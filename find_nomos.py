import sys
sys.path.insert(0, "/app")
from workers.common import load_clients_from_sheet

clients = load_clients_from_sheet("1E4TmhKLulzI9y7ag3yJJPIt8LmL_DGm1kzjuOFgOxMM")
for c in clients:
    if "номос" in c["name"].lower() or "nomos" in c["name"].lower():
        print(f"НАЙДЕН: {c}")
print(f"\nВсего: {len(clients)}")
for c in clients:
    print(f"  {c[_key]}: {c[name]} -> {c[spreadsheet_id]}")
