"""Fixed-capacity NumPy ring buffer for real-time chart data."""

from __future__ import annotations

import numpy as np


class RingBuffer:
    """Circular buffer backed by a NumPy array.

    Once full, new values overwrite the oldest entries.
    Reads always return data in chronological order.
    """

    def __init__(self, capacity: int, dtype=np.float64) -> None:
        if capacity < 1:
            raise ValueError("capacity must be >= 1")
        self._buf = np.zeros(capacity, dtype=dtype)
        self._capacity = capacity
        self._write_pos = 0
        self._count = 0

    @property
    def capacity(self) -> int:
        return self._capacity

    @property
    def count(self) -> int:
        """Number of valid elements currently stored."""
        return self._count

    @property
    def is_full(self) -> bool:
        return self._count >= self._capacity

    def append(self, value: float) -> None:
        """Add a single value, overwriting oldest if full."""
        self._buf[self._write_pos] = value
        self._write_pos = (self._write_pos + 1) % self._capacity
        if self._count < self._capacity:
            self._count += 1

    def extend(self, values: np.ndarray | list) -> None:
        """Append multiple values efficiently."""
        arr = np.asarray(values, dtype=self._buf.dtype)
        n = len(arr)
        if n == 0:
            return
        if n >= self._capacity:
            # Only keep the last `capacity` elements
            self._buf[:] = arr[-self._capacity:]
            self._write_pos = 0
            self._count = self._capacity
            return
        end = self._write_pos + n
        if end <= self._capacity:
            self._buf[self._write_pos : end] = arr
        else:
            first = self._capacity - self._write_pos
            self._buf[self._write_pos :] = arr[:first]
            self._buf[: n - first] = arr[first:]
        self._write_pos = end % self._capacity
        self._count = min(self._count + n, self._capacity)

    def get_all(self) -> np.ndarray:
        """Return all valid elements in chronological order (oldest first)."""
        if self._count == 0:
            return np.array([], dtype=self._buf.dtype)
        if self._count < self._capacity:
            return self._buf[: self._count].copy()
        # Buffer is full — data wraps around
        start = self._write_pos  # oldest element
        return np.concatenate([self._buf[start:], self._buf[:start]])

    def clear(self) -> None:
        """Reset the buffer (does not deallocate)."""
        self._write_pos = 0
        self._count = 0
        self._buf[:] = 0
