; I część boot loadera.
; Zajmuje się przeprowadzeniem symulacji gry w życie Conway'a.
; Symuluje kolejne generacje, aż do naciśnięcie klawisza.


org 0x7c00					; Informacja o początkowym adresie programu.

jmp 0:start					; Wyzerowanie rejestru cs.

INT_VECTOR_VIDEO equ 0x10			; Stała reprezentująca funkcję przerwań dot. karty graficznej.
INT_VECTOR_DRIVE equ 0x13			; Stała reprezentująca funkcję przerwań dot. dysku.
INT_VECTOR_KEYBOARD equ 0x16			; Stała reprezentująca funkcję przerwań dot. klawiatury.
INT_VECTOR_RTC equ 0x1a				; Stała reprezentująca funkcję przerwań dot. zegaru czasu rzeczywistego.

VIDEO_WRITE_CHAR equ 0x0e			; Stała reprezentująca funkcję do wypisywania znaków.

DRIVE_READ_SECTOR equ 0x02			; Stała reprezentująca funkcję do czytania sektorów.

KEYBOARD_READ_INPUT_STATUS equ 0x01		; Stała reprezentująca funkcję zwracającą, czy został wciśnięty klawisz.

STACK_INIT_ADDRESS equ 0x8000			; Adres zainicjowanego stosu.

SWAPPER_BL_ADDRESS equ 0x7a00			; Adres boot loadera II części, uruchamiającej oryginalny boot loader.
SWAPPER_BL_SIZE equ 0x01			; Rozmiar boot loadera II części w sektorach.
SWAPPER_BL_SECTOR equ 0x02 			; Numer sektora z kodem boot loadera II części.

DATA_ADDRESS equ 0x7200				; Adres danych, potrzebnych do symulacji gry w życie.
DATA_SIZE equ 0x05				; Rozmiar tych danych w sektorach.
DATA_SECTOR equ 0x04				; Numer sektora na dysku twardym, w którym te dane się rozpoczynają.

OLD_BOARD_ADDRESS equ 0x6a00			; Adres starej planszy gry w życie (poprzedniej generacji).
NEW_BOARD_ADDRESS equ 0x7200			; Adres nowej planszy gry w życie (poprzedniej generacji).

TICKS_VALUE_ADDRESS equ 0x7a00			; Adres wartości wskazującej ilości zmian statusu zegara.

BOARD_SIZE equ 0x0780				; Rozmiar planszy do gry w życie w bajtach.
COLUMN_SIZE equ 0x50				; Ilość kolumn planszy.
ROW_SIZE equ 0x18				; Ilość wierszy planszy.

ALIVE_CELL equ '#'				; Znak żywej komórki.
DEAD_CELL equ ' '				; Znak martwej komórki.

HARD_DISK_VALUE equ 0x80			; Wartość wskazująca na dysk z boot loaderem.

MAGIC_END_NUMBER equ 0xaa55			; Magiczna liczba, na której kończy się sektor MBR.


; Makro kopiujące dane z dysku twardego:
; %1 - Adres, na którym zostaną skopiowane dane.
; %2 - Rozmiar tych danych w sektorach.
; %3 - Numer sektora z początkiem danych.
%macro copy_sectors 3
	mov bx, %1				; Przekazanie odpowiednich parametrów do funkcji.
	mov al, %2
	mov cl, %3
	mov dl, HARD_DISK_VALUE

	xor ch, ch				; Przekazanie danych dot. głównego dysku twardego.
	xor dh, dh				; W przypadku MINIX'a jest to c0d0.

	mov ah, DRIVE_READ_SECTOR		; Wywołanie funkcji kopiującej dane we wcześniej podany adres.
	int INT_VECTOR_DRIVE
%endmacro

; Funkcja wypisująca planszę z nową generacją.
; Zmienia rejestry ax, bx i cx.
print_board:
	mov bx, NEW_BOARD_ADDRESS		; Zapisanie na rejestrach adresu nowej planszy oraz rozmiaru planszy.
	mov cx, BOARD_SIZE

.print_cell:
	mov ah, VIDEO_WRITE_CHAR		; Wypisanie komórki z planszy.
	mov al, [bx]
	int INT_VECTOR_VIDEO

	inc bx					; Przejście do kolejnej komórki.
	dec cx

	jnz .print_cell
.end:						; Zakończenie funkcji.
	ret					

; Funkcja wywołująca czekanie na daną ilość zmian statusu zegara.
; Zmienia rejestry ax, bx i dx.
wait_ticks:
	mov bx, [TICKS_VALUE_ADDRESS]		; Wczytanie wartości zmian statusu zegara.

	xor ah, ah				; Policzenie końcowej wartości zegara.
	int INT_VECTOR_RTC
	add bx, dx

.wait:
	xor ah, ah				; Przeczytanie wartości zegara.
	int INT_VECTOR_RTC

	cmp bx, dx				; Sprawdzenie, czy jest to końcowa wartość zegara.

	jne .wait				; Ponowne wywołanie pętli.

.end:						; Zakończenie funkcji.
	ret

; Funkcja kopiująca nową planszę na adres starej planszy.
; Funkcja również zapisuje nową planszę bajtami równymi zero.
; Modyfikuje rejestry bx i dx.
copy_board:
	mov bx, BOARD_SIZE			; Zapisanie rozmiaru planszy.

.copy_cell:
	dec bx

	mov dl, [bx + NEW_BOARD_ADDRESS]	; Przeniesienie danej komórki.
	mov [bx + OLD_BOARD_ADDRESS], dl

						; Wyzerowanie wartości nowej komórki.
	mov [bx + NEW_BOARD_ADDRESS], \
	    byte 0x00
	    

	jnz .copy_cell				; Przejście do kolejnej komórki.

.end:
	ret

; Funkcja, która zapisuje na rejestrze ah:al współrzędne komórki 
; oddalonej o dl kolumn od komórki o współrzędnych ch:cl.
; Funkcja zmienia wartość komórki ax.
move_column:
	mov al, cl				; Pobranie kolumny cl.
	add al, dl				; Zwiększenie kolumny cl o dl.
	cmp al, COLUMN_SIZE			; Sprawdzenie, czy nastąpi "skok" na początek.
	jb .end

	sub al, COLUMN_SIZE			; Jeżeli nastąpił skok, odejmowanie ilości kolumn od rejestru al.

.end:
	ret					; Zakończenie funkcji.


; Funkcja, która zapisuje na rejestrze ah:al współrzędne komórki 
; oddalonej o dh wierszy od komórki o współrzędnych ch:cl.
; Funkcja zmienia wartość komórki ax.
move_row:
	mov ah, ch				; Pobranie wierszy ch.
	add ah, dh				; Zwiększenie kolumny ch o dh.
	cmp ah, ROW_SIZE			; Sprawdzenie, czy nastąpi "skok" na początek.
	jb .end

	sub ah, ROW_SIZE			; Jeżeli nastąpił skok, odejmowanie ilości wierszy od rejestru ah.

.end:
	ret					; Zakończenie funkcji.

; Funkcja, która liczy dla danej komórki czy sąsiad
; oddalony o dh wierszy i dl kolumn jest żywy.
; Zwiększa ona wartość w nowej tablicy tej komórki o 1 jeżeli tak jest.
; Funkcja zmienia wartości rejestrów ax, bx, cx
count_cells:
	xor ch, ch				; Zaincjowanie nr wiersza na 0.

.count_row:
	xor cl, cl				; Zainicjowanie nr kolumny na 0.

.count_column:					
	xor bx, bx				; Wyczyszczenie rejestru bx.

	call move_column			; Zapisanie w rejestrze ax pozycji sąsiada.
	call move_row

.check_neighbour:
	mov bh, COLUMN_SIZE			; Przeniesienie wartości w odpowiednie rejestry do obliczeń.
	mov bl, al
	mov al, ah

	mul bh					; Policzenie pozycji sąsiada i zapisanie jej w rejestrze bx.
	xor bh, bh
	add bx, ax
						; Sprawdzenie czy sąsiad jest żywy.
	cmp [OLD_BOARD_ADDRESS + bx], \
	    byte ALIVE_CELL

	jnz .end_column				; Jeżeli nie, zakończenie liczenia dla tej kolumny w tym wierszu.

.count_cell:
	xor ax, ax				; Wyczyszczenie rejestrów.
	xor bx, bx

	mov bl, cl				; Przeniesienie rejestrów w odpowiednie miejsca do obliczeń.
	mov al, COLUMN_SIZE

	mul ch					; Obliczenie pozycji komórki.
	add bx, ax

	inc byte [NEW_BOARD_ADDRESS + bx]	; Zwiększenie liczby żywych sąsiadów.

.end_column:
	inc cl					; Zakończenie iterowania po kolumnach.
	cmp cl, byte COLUMN_SIZE
	jnz .count_column

.end_row:					; Zakończenie iterowania po wierszach.
	inc ch
	cmp ch, byte ROW_SIZE
	jnz .count_row
	
.end:						; Zakończenie funkcji.
	ret

; Funkcja tworząca nową generację i zapisująca ją na nowej planszy
; Zmienia ona rejestry ax i bx.
new_generation:
	xor bx, bx				; Wyczyszczenie rejestru bx.

.process_cell:
	mov al, byte [NEW_BOARD_ADDRESS + bx]	; Zapisanie ilości żywych sąsiadów.
						; Sprawdzenie czy komórka żyje.
	cmp [OLD_BOARD_ADDRESS + bx], \
	    byte ALIVE_CELL
	
	jnz .dead_cell

.alive_cell:					; Analiza żywej komórki.
	mov [NEW_BOARD_ADDRESS + bx], \
	    byte ALIVE_CELL			; Wstępnie uznanie, że komórka żyje.
						
	cmp al, byte 0x02			; Jeżeli ma 2 żywych sąsiadów żyje nadal.
	jz .process_next

	cmp al, byte 0x03			; Jeżeli ma 3 żywych sąsiadów żyje nadal.
	jz .process_next

	mov [NEW_BOARD_ADDRESS + bx], \
	    byte DEAD_CELL			; W przeciwnym przypadku umiera.
	
	jmp .process_next			; Przejście do kolejnej komórki

.dead_cell:					; Analiza martwej komórki.
	mov [NEW_BOARD_ADDRESS + bx], \
	    byte DEAD_CELL			; Wstępnie uznanie, że komórka jest martwa.

	cmp al, byte 0x03			; Jeżeli nie ma 3 żywych sąsiadów to jest martwa nadal.
	jnz .process_next

	mov [NEW_BOARD_ADDRESS + bx], \
	    byte ALIVE_CELL			; W przeciwnym przypadku odradza się.

.process_next:					; Iteracja po planszy.
	inc bx
	cmp bx, BOARD_SIZE

	jnz .process_cell

.end:						; Zakończenie funkcji.
	ret

; Funkcja symulująca jedną tury gry w życie.
; Stara plansza jest zapisywana w pamięci.
; Nowa plansza staje się miejscem zapisu żywych sąsiadów dla danej komórki.
; Dzięki tym danym, możliwe jest policzenie nowej generacji i zapisanie jej na nowej planszy.
game_of_life:
	call copy_board				; Skopiowanie nowej planszy w miejsce starej planszy.

	xor dx, dx				; Policzenie ilości żywych sąsiadów.
						; W rejestrze dx znajdują się wartości wskazujące, który sąsiad będzie sprawdzany.
						; Rejestr dh wskazuje na odległość wzdłuż rzędów od tego sąsiada.
						; Rejestr dl wskazuje na odległość wzdłuż kolumn od tego sąsiada.
						; Dla każdej komórki sprawdzany jest sąsiad na pozycji:

	mov dh, ROW_SIZE			; Górnej.
	dec dh
	call count_cells

	inc dl					; Prawej górnej.
	call count_cells

	mov dl, COLUMN_SIZE			; Lewej górnej.
	dec dl
	call count_cells

	xor dh, dh				; Lewej.
	call count_cells

	inc dh 					; Lewej dolnej.
	call count_cells

	xor dl, dl				; Dolnej.
	call count_cells

	inc dl					; Prawej dolnej.
	call count_cells

	xor dh, dh				; Prawej.
	call count_cells

	call new_generation			; Stworzenie nowej generacji.

.end:						; Zakończenie funkcji.
	ret

; Główna funkcja wywołująca poniższy algorytm:
; 1. Wyświetla aktualną generację, reprezentując żywą komórkę znakiem '#', a martwą komórkę spacją.
; 2. Czeka, aż N razy zmieni się stan zegara systemowego.
; 3. Jeśli naciśnięto jakiś klawisz, to przywraca stan dysku sprzed
;    instalacji rozwiązania i uruchamia MINIX-a oryginalnym boot loaderem.
; 4. Jeżeli nie naciśnięto klawisza, to liczy nową generację i przechodzi do pierwszego punktu.
start:

.init_registers:
	mov ax, cs				; Wyzerowanie pozostałych rejestrów segmentowych.
	mov ds, ax
	mov es, ax

.init_stack:
	mov ss, ax				; Inicjowanie stosu.
	mov sp, STACK_INIT_ADDRESS

.load_data:
						; Załadowanie danych potrzebnych do symulacji gry w życie.
	copy_sectors DATA_ADDRESS \
		     ,DATA_SIZE \
		     ,DATA_SECTOR

main_loop:
	call print_board			; Wypisanie planszy.

	call wait_ticks				; Czekanie na określoną liczbę zmian stanu systemu zegarowego.

.check_if_end:
	mov ah, KEYBOARD_READ_INPUT_STATUS	; Sprawdzenie, czy klawisz został wciśnięty.
	int INT_VECTOR_KEYBOARD

	jnz .load_second_part			; Jeżeli został, uruchomienie II część boot loadera.

	call game_of_life			; Jeżeli nie, symulacja gry w życie.

	jmp main_loop				; Skok do wypisywania planszy.

.load_second_part:
						; Załadowanie kodu drugiej części boot loadera.
	copy_sectors SWAPPER_BL_ADDRESS, \
		     SWAPPER_BL_SIZE, \
		     SWAPPER_BL_SECTOR

        jmp SWAPPER_BL_ADDRESS			; Uruchamianie II części boot loadera.

times (510 - $ + $$) db 0			; Wypełnienie reszty sektora zerami.
dw MAGIC_END_NUMBER				; Zakończenie sektora magiczną liczbą.