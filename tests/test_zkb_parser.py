import json
from pathlib import Path
import sys

SCRIPT_DIR = Path(__file__).resolve().parents[1] / 'DragonShield' / 'python_scripts'
sys.path.insert(0, str(SCRIPT_DIR))

import zkb_parser


def test_process_file(tmp_path, capsys):
    csv_content = (
        "Anlagekategorie;Anz./Nom.;Bezeichnung;Kurs;Währung\n"
        "Aktien und Ähnliches;10;Sample AG CH12345678901;100;CHF\n"
        "Konten;1000;Cash;1;CHF\n"
    )
    f = tmp_path / 'Depotauszug Mar 26 2025 ZKB.csv'
    f.write_text(csv_content, encoding='utf-8')

    code = zkb_parser.process_file(str(f))
    captured = capsys.readouterr().out
    data = json.loads(captured)

    assert code == 0
    assert data['summary']['total_data_rows_attempted'] == 2
    assert data['summary']['cash_account_records'] == 1
    assert data['summary']['security_holding_records'] == 1
    assert data['records'][0]['record_type'] == 'security_holding'
    assert data['records'][1]['record_type'] == 'cash_account'
