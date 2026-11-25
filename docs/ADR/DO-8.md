# DO-8: Projektovanje DNS zone

Status: prihvaćeno

## Kontekst

AO-7 traži vlastitu autoritativnu zonu (BIND) i adresiranje komponenti
isključivo imenima. AO-8 traži da zapisi budu Terraform resursi preko RFC 2136
i da TSIG ključ smije mijenjati samo zonu projekta. Zona je istovremeno i
dokumentacija plana adresiranja, pa mora biti jednostavna za provjeru.

## Razmotrene opcije

1. Jedna forward zona, bez reverse zone i bez round-robin-a.
2. Forward zona + reverse zone za oba segmenta + pripremljen round-robin.
3. Forward zona sa sekundarnim serverom (dvije instance BIND-a).

## Odluka

Opcija 2, sa sljedećim parametrima:

| Stavka | Odluka |
|---|---|
| zona | `ruo.local.` |
| TTL | 300 s (kratko — promjena i drift su odmah vidljivi) |
| zapisi | `web` → 172.28.10.10, `api` → 172.28.10.20, `db` → 172.28.20.30, `ns` → VM |
| reverse | `10.28.172.in-addr.arpa.` i `20.28.172.in-addr.arpa.`, PTR za sva tri imena |
| round-robin | **nije aktiviran** — jedna instanca backenda; zona je spremna za drugi A zapis |
| sekundarni | **ne** — nema drugog hosta |
| TSIG | ključ `ruo-key` (hmac-sha256), `allow-update` samo za zone projekta |

## Obrazloženje i posljedice

TTL 300 je kompromis: dovoljno dugo da se ne optereti server, dovoljno kratko
da drift demonstracija bude trenutna. Reverse zona nije obavezna, ali je jeftina
i dokazuje da zona nije „samo A zapisi".

Round-robin je razmotren i odbačen jer bi sa jednim backendom davao dva A zapisa
za istu adresu — to je lažna redundancija. Sekundarni server bi tražio drugu
instancu i ručno održavanje prenosa, a zadatak ga navodi samo kao primjer.

Posljedice: `ruo.local` pripada domenu rezervisanom za mDNS. U ovom okruženju
to ne smeta jer kontejneri i `dig` idu direktno na BIND i ne koriste mDNS, ali
u produkciji bi bolji izbor bio `.internal` ili vlastiti registrovani domen.
