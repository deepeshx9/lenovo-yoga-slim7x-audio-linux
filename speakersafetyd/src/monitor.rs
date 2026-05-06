//! telemetry.rs
//!
//! Slop-pseudocode!
//!
//! Concept module for speakersafetyd telemetry emission.
//!
//! This module defines the *interface + architecture* for exporting
//! safety state (limit, mode, gain reduction, etc.) to external consumers
//! such as GUI visualizers.
//!
//! NOTE:
//! This file is intentionally non-functional and contains no runtime logic.
//! It is a design scaffold for future implementation.

use std::time::Duration;

/// High-level safety state snapshot.
///
/// This is the canonical structure shared between:
/// - safety engine
/// - telemetry layer
/// - external visualizers
#[derive(Debug, Clone)]
pub struct SpeakerState {
    pub mode: SafetyMode,
    pub limit: f32,
    pub gain_reduction: f32,
    pub headroom: f32,
    pub timestamp: f64,
}

/// Safety operating modes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SafetyMode {
    Normal,
    Limiting,
    Muted,
}

/// Trait representing a generic telemetry output backend.
///
/// This abstraction allows multiple outputs without coupling:
/// - UNIX socket (Linux GUI)
/// - log file
/// - debugging console
/// - future NT named pipe backend
pub trait TelemetrySink {
    fn emit(&self, state: &SpeakerState);
}

/// Central telemetry controller.
///
/// Conceptually responsible for:
/// - receiving state snapshots from the safety engine
/// - deciding when to emit (throttle / state-change driven)
/// - forwarding to a sink
pub struct TelemetryController<S: TelemetrySink> {
    sink: S,

    /// last emitted state (for diff-based emission)
    last_state: Option<SpeakerState>,

    /// emission rate limiter (conceptual)
    min_interval: Duration,
}

impl<S: TelemetrySink> TelemetryController<S> {
    /// Create a new telemetry controller.
    pub fn new(sink: S, min_interval: Duration) -> Self {
        Self {
            sink,
            last_state: None,
            min_interval,
        }
    }

    /// Conceptual update entry point.
    ///
    /// This is called by the safety engine AFTER state is finalized.
    ///
    /// Intended behavior (NOT IMPLEMENTED HERE):
    /// - compare with last state
    /// - emit only if changed OR interval elapsed
    pub fn update(&mut self, state: SpeakerState) {
        // DESIGN NOTE:
        // In real implementation:
        // - diff state vs last_state
        // - enforce min_interval
        // - optionally batch or queue

        self.last_state = Some(state.clone());

        self.sink.emit(&state);
    }
}

/// Conceptual helper: snapshot builder hook.
///
/// In the real system, this would be called from the safety engine
/// after limiter + protection logic has fully resolved.
pub fn build_snapshot(
    mode: SafetyMode,
    limit: f32,
    gain_reduction: f32,
) -> SpeakerState {
    SpeakerState {
        mode,
        limit,
        gain_reduction,
        headroom: 1.0 - limit,
        timestamp: 0.0, // placeholder (would be system time)
    }
}

/// ---- DESIGN NOTES ----
///
/// Injection points in the Rust codebase:
///
/// 1. SAFETY STATE TRANSITION:
///    - call TelemetryController::update() whenever state changes
///
/// 2. MAIN UPDATE LOOP (fallback):
///    - periodic snapshot emission (e.g., 10–20 Hz)
///
/// 3. NEVER:
///    - per-sample DSP
///    - inner clamp math
///    - audio callback threads
///
///
/// Data flow concept:
///
///     audio/safety engine
///             ↓
///      state machine resolves
///             ↓
///     build_snapshot()
///             ↓
///  TelemetryController::update()
///             ↓
///      TelemetrySink (UNIX socket)
///             ↓
///     Python visualizer (GUI)
///
///
/// Future extensions:
/// - gain reduction history buffer
/// - peak/hold metadata
/// - predictive limiting (headroom forecasting)
/// - multi-zone speaker telemetry