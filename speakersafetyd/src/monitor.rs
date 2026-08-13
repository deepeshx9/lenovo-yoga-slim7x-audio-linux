use serde::Serialize;
use std::os::unix::net::UnixDatagram;
use std::time::{Duration, Instant};

/// High-level safety state snapshot.
/// Now derives Serialize so it can instantly become JSON.
#[derive(Debug, Clone, Serialize)]
pub struct SpeakerState {
    pub mode: SafetyMode,
    pub limit: f32,
    pub gain_reduction: f32,
    pub headroom: f32,
    pub timestamp: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum SafetyMode {
    Normal,
    Limiting,
    Muted,
}

/// Trait representing a generic telemetry output backend.
pub trait TelemetrySink {
    fn emit(&self, state: &SpeakerState);
}

/// A fire-and-forget UNIX Datagram socket implementation.
pub struct UdsTelemetrySink {
    socket: UnixDatagram,
    target_path: String,
}

impl UdsTelemetrySink {
    pub fn new(target_path: &str) -> std::io::Result<Self> {
        // Bind to an unbound socket for sending datagrams
        let socket = UnixDatagram::unbound()?;
        // Set non-blocking just to be absolutely safe
        socket.set_nonblocking(true)?;
        
        Ok(Self {
            socket,
            target_path: target_path.to_string(),
        })
    }
}

impl TelemetrySink for UdsTelemetrySink {
    fn emit(&self, state: &SpeakerState) {
        // Serialize the state to a JSON string
        if let Ok(json_string) = serde_json::to_string(state) {
            // Fire and forget. We intentionally ignore errors (e.g., if the GUI isn't running)
            let _ = self.socket.send_to(json_string.as_bytes(), &self.target_path);
        }
    }
}

/// Central telemetry controller with actual throttling logic.
pub struct TelemetryController<S: TelemetrySink> {
    sink: S,
    last_state: Option<SpeakerState>,
    min_interval: Duration,
    last_emit_time: Option<Instant>,
}

impl<S: TelemetrySink> TelemetryController<S> {
    pub fn new(sink: S, min_interval: Duration) -> Self {
        Self {
            sink,
            last_state: None,
            min_interval,
            last_emit_time: None,
        }
    }

    pub fn update(&mut self, state: SpeakerState) {
        let now = Instant::now();
        let mut should_emit = false;

        // Condition 1: Time interval elapsed (e.g., 10Hz tick)
        if let Some(last_time) = self.last_emit_time {
            if now.duration_since(last_time) >= self.min_interval {
                should_emit = true;
            }
        } else {
            should_emit = true; // First run
        }

        // Condition 2: Critical state change (e.g., went from Normal to Limiting)
        // We want to emit immediately, bypassing the throttle, so the GUI feels instant.
        if let Some(ref last) = self.last_state {
            if last.mode != state.mode {
                should_emit = true;
            }
        }

        if should_emit {
            self.sink.emit(&state);
            self.last_emit_time = Some(now);
            self.last_state = Some(state);
        }
    }
}