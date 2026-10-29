"""Referência independente da P5.

Lê o csv exportado pelo EA de teste (``time,close,sma``), recalcula a SMA(12)
a partir dos fechos do próprio csv, em Decimal, e compara com o buffer lido por
``iCustom``. Não usa o código MQL5. Sem rede. Escreve um JSON numa linha em
stdout e sai com 0 só se a comparação passar.
"""

from __future__ import annotations

import json
import sys
from decimal import Decimal, InvalidOperation

PERIOD = 12
TOLERANCE = Decimal("0.00000001")
MINIMUM_COMPARED = 100


def main(path: str) -> int:
    try:
        with open(path, encoding="utf-8-sig") as handle:
            lines = [line.strip() for line in handle if line.strip()]
    except OSError:
        print(json.dumps({"ok": False, "erro": "csv ilegivel"}))
        return 1
    if not lines or lines[0] != "time,close,sma":
        print(json.dumps({"ok": False, "erro": "cabecalho invalido"}))
        return 1
    closes: list[Decimal] = []
    smas: list[Decimal] = []
    times: list[str] = []
    for line in lines[1:]:
        parts = line.split(",")
        if len(parts) != 3:
            print(json.dumps({"ok": False, "erro": "linha invalida"}))
            return 1
        try:
            closes.append(Decimal(parts[1]))
            smas.append(Decimal(parts[2]))
        except InvalidOperation:
            print(json.dumps({"ok": False, "erro": "valor nao numerico"}))
            return 1
        times.append(parts[0])
    if len(set(times)) != len(times) or times != sorted(times):
        print(json.dumps({"ok": False, "erro": "barras repetidas ou fora de ordem"}))
        return 1
    compared = 0
    worst = Decimal(0)
    worst_time = None
    for index in range(PERIOD - 1, len(closes)):
        expected = sum(closes[index - PERIOD + 1 : index + 1]) / PERIOD
        diff = abs(expected - smas[index])
        compared += 1
        if diff > worst:
            worst = diff
            worst_time = times[index]
    ok = compared >= MINIMUM_COMPARED and worst <= TOLERANCE
    print(
        json.dumps(
            {
                "ok": ok,
                "linhas": len(closes),
                "comparadas": compared,
                "minimo": MINIMUM_COMPARED,
                "max_diff": str(worst),
                "max_diff_em": worst_time,
                "tolerancia": str(TOLERANCE),
            },
            sort_keys=True,
        )
    )
    return 0 if ok else 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(json.dumps({"ok": False, "erro": "uso: p5_referencia.py <csv>"}))
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
