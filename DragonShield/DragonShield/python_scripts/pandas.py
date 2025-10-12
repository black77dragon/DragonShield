class Series(list):
    def __init__(self, data):
        super().__init__(float(x) for x in data)

    def mean(self):
        return sum(self) / len(self) if self else 0.0

    def std(self):
        m = self.mean()
        return (sum((x - m) ** 2 for x in self) / len(self)) ** 0.5 if self else 0.0

    def cumprod(self):
        out = []
        total = 1.0
        for x in self:
            total *= x
            out.append(total)
        return Series(out)

    def cummax(self):
        out = []
        m = float('-inf')
        for x in self:
            m = max(m, x)
            out.append(m)
        return Series(out)

    def quantile(self, q):
        data = sorted(self)
        if not data:
            return 0.0
        idx = int((len(data) - 1) * q)
        return data[idx]

    def __sub__(self, other):
        if isinstance(other, (int, float)):
            return Series([x - other for x in self])
        return Series([a - b for a, b in zip(self, other)])

    def __add__(self, other):
        if isinstance(other, (int, float)):
            return Series([x + other for x in self])
        return Series([a + b for a, b in zip(self, other)])

    __radd__ = __add__

    def __mul__(self, other):
        if isinstance(other, (int, float)):
            return Series([x * other for x in self])
        return Series([a * b for a, b in zip(self, other)])

    def __truediv__(self, other):
        return Series([x / other for x in self])

    def __lt__(self, value):
        return [x < value for x in self]

    def __getitem__(self, key):
        if isinstance(key, list):
            return Series([x for x, k in zip(self, key) if k])
        result = super().__getitem__(key)
        if isinstance(result, list):
            return Series(result)
        return result
