; II część boot loadera.
; Zajmuje się ona uruchomieniem oryginalnego boot loadera.
; Kopiuje ona zawartość oryginału i go uruchamia.
org 0x7a00

INT_VECTOR_DRIVE equ 0x13			; Stała reprezentująca funkcję przerwań dot. dysku.

DRIVE_READ_SECTOR equ 0x02			; Stała reprezentująca funkcję do czytania sektorów.

ORIG_BL_ADDRESS equ 0x7c00			; Adres, do którego zostanie skopiowany oryginalny boot loader.
ORIG_BL_SIZE equ 0x01				; Rozmiar oryginalnego boot loadera w sektorach.
ORIG_BL_SECTOR equ 0x03				; Numer sektora, w którym rozpoczyna się kod oryginalnego boot loadera.

start:
	mov bx, ORIG_BL_ADDRESS			; Przekazanie odpowiednich parametrów dot. oryginalnego boot loadera.
	mov al, ORIG_BL_SIZE
	mov cl, ORIG_BL_SECTOR

	xor ch, ch				; Przekazanie danych dot. głównego dysku twardego.
	xor dh, dh				; W przypadku MINIX'a jest to c0d0.
	
	mov ah, DRIVE_READ_SECTOR		; Wywołanie funkcji kopiującej dane we wcześniej podany adres.
    	int INT_VECTOR_DRIVE

	jmp ORIG_BL_ADDRESS			; Skok, powodujący uruchomienie oryginalnego boot loadera.