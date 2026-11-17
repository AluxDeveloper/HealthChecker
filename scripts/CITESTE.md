# Sarcini – instalare pe simulatorul iOS

Ai nevoie de un **Mac** cu **Xcode** instalat (din App Store, deschis măcar o dată).

## Instalare (o singură dată)

1. Dezarhivează `Sarcini-simulator.zip` (dublu-click).
2. Deschide **Terminal**, scrie `zsh ` (cu spațiu după), trage în fereastră
   fișierul `instaleaza.sh` din folderul `Sarcini` și apasă Enter.

Scriptul pornește un iPhone în **Device Hub**, instalează aplicația și o deschide.

## Folosire

Aplicația **Sarcini** rămâne pe iPhone-ul din Device Hub, ca orice aplicație.

Sarcinile se salvează automat în cloud (Supabase), într-un cont anonim
creat la prima pornire: fiecare persoană își vede doar sarcinile ei.
E nevoie de internet doar pentru sincronizare; fără internet aplicația
merge mai departe și trimite datele când revine legătura.

Sarcinile șterse sau a căror oră a trecut stau 3 zile în **Istoric**
(butonul cu ceas, dreapta sus), apoi dispar definitiv.
