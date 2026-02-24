"""Tests for core/ring_buffer.py — fixed-capacity numpy ring buffer."""

import numpy as np
import pytest

from src.core.ring_buffer import RingBuffer


class TestRingBufferBasics:
    def test_empty_buffer(self):
        buf = RingBuffer(10)
        assert buf.count == 0
        assert buf.capacity == 10
        assert not buf.is_full
        assert len(buf.get_all()) == 0

    def test_append_single(self):
        buf = RingBuffer(5)
        buf.append(3.14)
        assert buf.count == 1
        assert buf.get_all()[0] == pytest.approx(3.14)

    def test_append_fills(self):
        buf = RingBuffer(3)
        buf.append(1.0)
        buf.append(2.0)
        buf.append(3.0)
        assert buf.is_full
        assert buf.count == 3
        np.testing.assert_array_almost_equal(buf.get_all(), [1.0, 2.0, 3.0])

    def test_wrap_around(self):
        buf = RingBuffer(3)
        for v in [1.0, 2.0, 3.0, 4.0, 5.0]:
            buf.append(v)
        assert buf.is_full
        assert buf.count == 3
        np.testing.assert_array_almost_equal(buf.get_all(), [3.0, 4.0, 5.0])

    def test_clear(self):
        buf = RingBuffer(5)
        buf.extend([1.0, 2.0, 3.0])
        buf.clear()
        assert buf.count == 0
        assert len(buf.get_all()) == 0


class TestRingBufferExtend:
    def test_extend_fits(self):
        buf = RingBuffer(10)
        buf.extend([1.0, 2.0, 3.0])
        assert buf.count == 3
        np.testing.assert_array_almost_equal(buf.get_all(), [1.0, 2.0, 3.0])

    def test_extend_wraps(self):
        buf = RingBuffer(4)
        buf.extend([1.0, 2.0, 3.0])
        buf.extend([4.0, 5.0, 6.0])
        # capacity=4, should have [3, 4, 5, 6]
        assert buf.count == 4
        np.testing.assert_array_almost_equal(buf.get_all(), [3.0, 4.0, 5.0, 6.0])

    def test_extend_larger_than_capacity(self):
        buf = RingBuffer(3)
        buf.extend([1.0, 2.0, 3.0, 4.0, 5.0])
        assert buf.count == 3
        np.testing.assert_array_almost_equal(buf.get_all(), [3.0, 4.0, 5.0])

    def test_extend_empty(self):
        buf = RingBuffer(5)
        buf.extend([])
        assert buf.count == 0

    def test_extend_with_numpy_array(self):
        buf = RingBuffer(5)
        buf.extend(np.array([10.0, 20.0, 30.0]))
        assert buf.count == 3
        np.testing.assert_array_almost_equal(buf.get_all(), [10.0, 20.0, 30.0])


class TestRingBufferEdgeCases:
    def test_capacity_one(self):
        buf = RingBuffer(1)
        buf.append(1.0)
        assert buf.get_all()[0] == pytest.approx(1.0)
        buf.append(2.0)
        assert buf.get_all()[0] == pytest.approx(2.0)
        assert buf.count == 1

    def test_invalid_capacity_raises(self):
        with pytest.raises(ValueError):
            RingBuffer(0)
        with pytest.raises(ValueError):
            RingBuffer(-1)

    def test_get_all_returns_copy(self):
        buf = RingBuffer(5)
        buf.extend([1.0, 2.0, 3.0])
        arr = buf.get_all()
        arr[0] = 999.0
        # Original unchanged
        assert buf.get_all()[0] == pytest.approx(1.0)
