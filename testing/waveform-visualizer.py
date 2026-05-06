### Slop-pseudocode!!
### We are working on a functional alternative in the meantime


import sys
import argparse
import numpy as np
import random

from PySide6.QtWidgets import QApplication, QMainWindow
from PySide6.QtCore import QTimer
import pyqtgraph as pg


# ==============================
# CONFIG / FLAGS
# ==============================

parser = argparse.ArgumentParser()
parser.add_argument("--experimental", action="store_true")
args = parser.parse_args()

EXPERIMENTAL = args.experimental


# ==============================
# AUDIO SOURCE (DUMMY)
# ==============================

class AudioSource:
    def __init__(self, max_size=2048):
        self.buffer = np.zeros(max_size)
        self.max_size = max_size

    def update(self):
        # simulate audio: noise + occasional spikes
        samples = np.random.normal(0, 0.2, 256)

        if random.random() < 0.1:
            samples += np.random.normal(0, 0.8, 256)

        self.buffer = np.roll(self.buffer, -len(samples))
        self.buffer[-len(samples):] = samples

    def get_buffer(self):
        return self.buffer.copy()


# ==============================
# SAFETY BACKEND (DUMMY)
# ==============================

class SafetyBackend:
    def __init__(self):
        self.state = "normal"
        self.limit = 1.0
        self.counter = 0

    def update(self):
        self.counter += 1

        # change state every ~2 seconds
        if self.counter % 120 == 0:
            self.state = random.choice(["normal", "limiting", "muted"])

            if self.state == "limiting":
                self.limit = random.uniform(0.2, 0.7)

            elif self.state == "muted":
                self.limit = 0.0

            else:
                self.limit = 1.0

    def get_state(self):
        return {
            "state": self.state,
            "limit": self.limit
        }


# ==============================
# SIGNAL PROCESSING
# ==============================

class SignalProcessor:
    def __init__(self):
        self.smoothed_rms = 0.0

    def compute_rms(self, data):
        return np.sqrt(np.mean(data ** 2))

    def smooth(self, prev, new, alpha=0.2):
        return alpha * new + (1 - alpha) * prev

    def process(self, buffer):
        raw_rms = self.compute_rms(buffer)
        self.smoothed_rms = self.smooth(self.smoothed_rms, raw_rms)
        return self.smoothed_rms


# ==============================
# VISUALIZER (GUI)
# ==============================

class Visualizer(QMainWindow):
    def __init__(self, audio, safety, processor):
        super().__init__()

        self.audio = audio
        self.safety = safety
        self.processor = processor

        self.setWindowTitle("Audio Safety Visualizer (Dummy)")
        self.resize(400, 300)

        # Plot
        self.plot = pg.PlotWidget()
        self.setCentralWidget(self.plot)

        self.plot.setYRange(0, 1)
        self.plot.setXRange(-1, 1)
        self.plot.hideAxis('bottom')

        # Bars
        self.output_bar = pg.BarGraphItem(x=[0], height=[0], width=0.5, brush='g')
        self.raw_bar = pg.BarGraphItem(x=[0], height=[0], width=0.5, brush=(100, 100, 255, 80))
        self.overflow_bar = pg.BarGraphItem(x=[0], height=[0], width=0.5, brush='r')

        self.plot.addItem(self.raw_bar)
        self.plot.addItem(self.output_bar)
        self.plot.addItem(self.overflow_bar)

        # Limit line
        self.limit_line = pg.InfiniteLine(angle=0, pen=pg.mkPen('y', width=2))
        self.plot.addItem(self.limit_line)

        # Timer
        self.timer = QTimer()
        self.timer.timeout.connect(self.update)
        self.timer.start(16)  # ~60 FPS

    def update(self):
        # --- update sources ---
        self.audio.update()
        self.safety.update()

        # --- get data ---
        buffer = self.audio.get_buffer()
        safety_state = self.safety.get_state()

        # --- process signal ---
        rms = self.processor.process(buffer)
        limit = safety_state["limit"]

        # --- compute ---
        output_level = min(rms, limit)
        overflow = max(0, rms - limit)

        # --- update visuals ---
        self.raw_bar.setOpts(height=[rms])
        self.output_bar.setOpts(height=[output_level])

        # overflow sits above limit
        self.overflow_bar.setOpts(height=[overflow], y0=limit)

        self.limit_line.setValue(limit)

        # --- color logic ---
        if safety_state["state"] == "muted":
            self.output_bar.setOpts(brush='r')

        elif safety_state["state"] == "limiting":
            self.output_bar.setOpts(brush='y')

        else:
            self.output_bar.setOpts(brush='g')


# ==============================
# MAIN ENTRY
# ==============================

def main():
    app = QApplication(sys.argv)

    audio = AudioSource()
    safety = SafetyBackend()
    processor = SignalProcessor()

    vis = Visualizer(audio, safety, processor)
    vis.show()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()