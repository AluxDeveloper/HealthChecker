# Sarcini – instalare pe simulatorul iOS

Ai nevoie de un **Mac** cu **Xcode** instalat (din App Store, deschis măcar o dată).

## Instalare (o singură dată)

1. Dezarhivează `Sarcini-simulator.zip` (dublu-click).
2. Deschide **Terminal** și scrie `zsh ` (cu spațiu după), apoi trage în
   fereastră fișierul `instaleaza.sh` din folderul `Sarcini` și apasă Enter.

Scriptul face singur tot:
- instalează și pornește **PostgreSQL** dacă lipsește (prin Homebrew – dacă
  nu ai Homebrew, îl instalezi de pe https://brew.sh);
- creează baza de date `sarcini`;
- pornește un iPhone în **Device Hub** și deschide aplicația.

## Folosire

După instalare, aplicația **Sarcini** rămâne pe iPhone-ul din Device Hub,
ca orice aplicație: o deschizi de pe ecranul principal al simulatorului.

Datele se salvează în baza ta de date locală. Le poți vedea cu:

```
psql -d sarcini -c "select * from tasks"
```

Sarcinile șterse sau a căror oră a trecut stau 3 zile în **Istoric**
(butonul cu ceas, dreapta sus), apoi dispar definitiv.
