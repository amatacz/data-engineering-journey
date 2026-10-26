from dotenv import load_dotenv
import os
import psycopg2
import requests

def fetch_rates(start: str = '2024-01-01', end: str ='2024-03-31', base: str = 'EUR', symbols: list[str] = ['GBP', 'PLN', 'USD']) -> dict:
    base_url = 'https://api.frankfurter.dev/v1/'
    symbols_str = ",".join(symbols)
    endpoint_url = f"{base_url}{start}..{end}?base={base}&symbols={symbols_str}"

    r = requests.get(endpoint_url, timeout=10)
    r.raise_for_status()

    return r.json()

def transform_rates(payload: dict) -> list[tuple]:
    results = []
    base = payload.get('base')

    for rate_date, currencies in payload['rates'].items():
        for target, rate in currencies.items():
            if not rate or rate <= 0:
                continue
            inverse_rate = round(1 / rate, 8)
            results.append((rate_date, base, target, rate, inverse_rate))
    return results
            
def connect_to_db():
    load_dotenv()

    DB_HOST = os.getenv('DB_HOST')
    DB_DATABASE = os.getenv('DB_NAME')
    DB_USER = os.getenv('DB_USER')
    DB_PASSWORD = os.getenv('DB_PASSWORD')

    try:
        connection = psycopg2.connect(
            host=DB_HOST, 
            database=DB_DATABASE, 
            user=DB_USER, 
            password=DB_PASSWORD)
        print("DB Connected")
    except Exception as e:
        print(f"Issues with DB connection {e}")
    return connection

def write_rates(rows: list[tuple], conn) -> int:
    cur = conn.cursor()
    rows_count = 0
    for row in rows:
        cur.execute(f"""
                    INSERT INTO postgres.week05.exchange_rates (rate_date, base_currency, target_currency, rate, inverse_rate)
                    VALUES {row}
                    ON CONFLICT (rate_date, base_currency, target_currency) DO UPDATE SET 
                        rate = EXCLUDED.rate,
                        inverse_rate = EXCLUDED.inverse_rate;"""
        )
        conn.commit()
        rows_count += 1
    conn.close()
    print("Rows affected: ", rows_count)
    return rows_count



def main():
    api_rates = fetch_rates()
    rates = transform_rates(api_rates)
    connection = connect_to_db()

    write_rates(rates, connection)


main()
