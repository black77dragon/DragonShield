import json
from pathlib import Path
import sys

SCRIPT_DIR = Path(__file__).resolve().parents[1] / 'DragonShield' / 'python_scripts'
sys.path.insert(0, str(SCRIPT_DIR))

import zkb_parser


def test_basic_parsing(tmp_path):
    csv_content = (
        'Anlagekategorie,Anz./Nom.,Einstandskurs,Marktkurs,Währung,Bezeichnung,Valor/IBAN/MSCI ESG-Rating\n'
        'Equities (EU),10,20,25,EUR,Sample Corp,12345\n'
    )
    f = tmp_path / 'sample.csv'
    f.write_text(csv_content, encoding='utf-8')

    result_json = Path('out.json')
    data = None
    # capture stdout
    import io
    import contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        zkb_parser.process_file(str(f))
    data = json.loads(buf.getvalue())

    assert data['summary']['data_rows_successfully_parsed'] == 1
    rec = data['records'][0]
    assert rec['quantity'] == 10
    assert rec['purchase_price'] == 20
    assert rec['current_price'] == 25
    assert rec['currency'] == 'EUR'
    assert rec['asset_class_code'] == 'EQT'
