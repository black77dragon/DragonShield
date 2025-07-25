from typing import Iterable, Mapping, MutableMapping, Sequence, Any, Dict, Set, List


def filter_instruments(
    instruments: Iterable[Mapping[str, Any]],
    filters: Mapping[str, Set[Any]],
) -> List[Mapping[str, Any]]:
    """Return instruments matching stacked column filters."""
    result: List[Mapping[str, Any]] = []
    for inst in instruments:
        include = True
        for column, allowed in filters.items():
            if allowed and inst.get(column) not in allowed:
                include = False
                break
        if include:
            result.append(dict(inst))
    return result


__all__ = ["filter_instruments"]
