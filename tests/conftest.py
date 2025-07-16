import sys
import types

class FakeSeries(list):
    def __sub__(self, other):
        if isinstance(other, (int, float)):
            return FakeSeries([x - other for x in self])
        if isinstance(other, FakeSeries):
            return FakeSeries([a - b for a, b in zip(self, other)])
        return NotImplemented

    def __truediv__(self, other):
        if isinstance(other, (int, float)):
            return FakeSeries([x / other for x in self])
        if isinstance(other, FakeSeries):
            return FakeSeries([a / b for a, b in zip(self, other)])
        return NotImplemented

    def mean(self):
        return sum(self) / len(self) if self else 0.0

    def std(self):
        m = self.mean()
        return (sum((x - m) ** 2 for x in self) / len(self)) ** 0.5 if self else 0.0

    def cumprod(self):
        out = []
        acc = 1.0
        for x in self:
            acc *= (1 + x)
            out.append(acc)
        return FakeSeries(out)

    def cummax(self):
        out = []
        current = float('-inf')
        for x in self:
            current = x if x > current else current
            out.append(current)
        return FakeSeries(out)

    def quantile(self, q):
        if not self:
            return 0.0
        arr = sorted(self)
        idx = int((len(arr) - 1) * q)
        return arr[idx]

    def min(self):
        return min(x for x in self) if self else 0.0

    def astype(self, _type):
        if _type is float:
            return FakeSeries([float(x) for x in self])
        return self

    def __getitem__(self, key):
        if isinstance(key, FakeSeries):
            return FakeSeries([x for x, flag in zip(self, key) if flag])
        return FakeSeries(super().__getitem__(key)) if isinstance(key, slice) else super().__getitem__(key)

    def __lt__(self, other):
        if isinstance(other, (int, float)):
            return FakeSeries([x < other for x in self])
        if isinstance(other, FakeSeries):
            return FakeSeries([a < b for a, b in zip(self, other)])
        return NotImplemented

    def __radd__(self, other):
        if isinstance(other, (int, float)):
            return FakeSeries([other + x for x in self])
        return NotImplemented


def Series(data):
    return FakeSeries(list(data))

fake_pandas = types.ModuleType('pandas')
fake_pandas.Series = Series
fake_pandas.read_csv = lambda *a, **k: None

sys.modules.setdefault('pandas', fake_pandas)

import math
fake_numpy = types.ModuleType('numpy')
fake_numpy.sqrt = math.sqrt
sys.modules.setdefault('numpy', fake_numpy)
