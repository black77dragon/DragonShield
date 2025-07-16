import sys, types, math

# Minimal numpy stub
numpy_stub = types.SimpleNamespace(sqrt=math.sqrt, array=lambda x:x)
sys.modules.setdefault('numpy', numpy_stub)

# Minimal pandas stub
class Series(list):
    def __init__(self, data):
        super().__init__(float(x) for x in data)
    def mean(self):
        return sum(self)/len(self) if self else 0.0
    def std(self):
        m=self.mean()
        if not self:
            return 0.0
        var=sum((x-m)**2 for x in self)/len(self)
        return math.sqrt(var)
    def __add__(self, other):
        if isinstance(other, (int, float)):
            return Series([x+other for x in self])
        if isinstance(other, Series):
            return Series([x+y for x,y in zip(self, other)])
        return NotImplemented
    __radd__=__add__
    def __sub__(self, other):
        if isinstance(other, (int, float)):
            return Series([x-other for x in self])
        if isinstance(other, Series):
            return Series([x-y for x,y in zip(self, other)])
        return NotImplemented
    def __rsub__(self, other):
        if isinstance(other, (int, float)):
            return Series([other-x for x in self])
        return NotImplemented
    def __mul__(self, other):
        if isinstance(other, (int,float)):
            return Series([x*other for x in self])
        if isinstance(other, Series):
            return Series([x*y for x,y in zip(self, other)])
        return NotImplemented
    __rmul__=__mul__
    def __truediv__(self, other):
        if isinstance(other, (int,float)):
            return Series([x/other for x in self])
        if isinstance(other, Series):
            return Series([x/y for x,y in zip(self, other)])
        return NotImplemented
    def __lt__(self, other):
        return [x<other for x in self]
    def __getitem__(self, key):
        if isinstance(key, list):
            return Series([x for x, k in zip(self, key) if k])
        return float(super().__getitem__(key))
    def cumprod(self):
        out=[]; prod=1.0
        for x in self:
            prod*=x
            out.append(prod)
        return Series(out)
    def cummax(self):
        out=[]; m=float('-inf')
        for x in self:
            m=max(m,x); out.append(m)
        return Series(out)
    def quantile(self,q):
        if not self:
            return 0.0
        s=sorted(self)
        idx=int((len(s)-1)*q)
        return s[idx]
    def min(self):
        return min(self) if self else 0.0

pandas_stub = types.ModuleType('pandas')
pandas_stub.Series = Series
sys.modules.setdefault('pandas', pandas_stub)
