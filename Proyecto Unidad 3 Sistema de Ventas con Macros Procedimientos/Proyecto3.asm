;Desarrolla un sistema de consola en MASM x86 de 32 bits con Irvine32.
;El negocio es de eleccion libre: elegimos papeleria.

INCLUDE Irvine32.inc

limiteProductos = 10 ;cantidad

;MACROS
;mMostrar va a imprimir una cadena con su terminador nulo
;Recibe como parametro el mensaje = nombre de la variable con el texto
;Conserva a edx guardandolo en la pila y regresandolo
mMostrar MACRO mensaje
	push edx
	mov edx, OFFSET mensaje
	call WriteString
	pop edx
ENDM

;mLeerCadena va a leer el texto del teclado en un buffer
;Recibe el buffer = nombre del buffer donde se guarda lo escrito
;Devuelve los registros de eax = caracteres leidos, edx = offset buffer
;Modifica los registros de eax, ecx y edx
mLeerCadena MACRO buffer
	mov edx, OFFSET buffer
	mov ecx, SIZEOF buffer - 1
	call ReadString
ENDM

;mPonerCaracter va a escribir un caracter en [edi] y avanzara a edi
;Recibe el caracter y edi = destino
;Devuelve a edi apuntando al siguiente lugar libre
;Modifica el registro de al
mPonerCaracter MACRO caracter
	mov al, caracter
	mov [edi], al
	inc edi
ENDM

;mDesplazamiento. Esta macro calcula el desplazamiento de un producto dentro de un arreglo paralelo
;Recibe el indice y el tama o
;Devuelve a eax = desplazamiento
;Modifica los registros de eax, ebx y edx
mDesplazamiento MACRO indice, tamano
	mov eax, indice
	mov ebx, tamano
	mul ebx
ENDM

;mCopiarBytes copia una cantidad fija de bytes de un origen al destino
;Recibe el destino, origen y la cantidad
;Conserva los registros de eax, ecx, esi, edi
;Se utiliza LOCAL en la etiqueta ciclo para que reciba un nombre distinto en cada expansion,
;asi la macro se puede usar varias veces
mCopiarBytes MACRO destino, origen, cantidad
	LOCAL ciclo
	push eax
	push ecx
	push esi
	push edi
	mov esi, origen
	mov edi, destino
	mov ecx, cantidad
ciclo:
	mov al, [esi]
	mov [edi], al
	inc esi
	inc edi
	loop ciclo
	pop edi
	pop esi
	pop ecx
	pop eax
ENDM

;mOpcion es para una opcion del menu, donde si al = caracter, llama al procedimiento y regresa al menu
;Recibe el caracter del '1' al '8' y el procedimiento = nombre del PROC
;Se utiliza LOCAL siguiente para que reciba un nombre distinto en cada uno de los 8 usos
mOpcion MACRO caracter, procedimiento
	LOCAL siguiente

	cmp al, caracter
	jne siguiente

	call procedimiento
	jmp menu
siguiente:
ENDM

;El valor de error que se usa en el proyecto es eax=-1
;mSiError salta a la etiqueta si eax = -1
mSiError MACRO etiqueta
	cmp eax, -1
	je etiqueta
ENDM

;mTerminarConExito va a actualizar la bandera de cambios e imprime el mensaje de procedimiento exitoso
;Recibe el parametro de estado = 1 o 0, catalogo guardado/cargado
mTerminarConExito MACRO estado
	mov cambiosSinGuardar, estado
	call mensajeExito
ENDM

;mMostrarImporte imprime un mensaje seguido de una cantidad en pesos
;Recibe el mensaje y el valor = centavos
;Modifica el registro de eax
mMostrarImporte MACRO mensaje, valor
	mMostrar mensaje
	mov eax, valor
	call imprimirDinero
ENDM

;mAbrirArchivo abre o crea Catalogo.txt y guarda el handle
;Recibe la funcion, ya sea CreateOutputFile u OpenInputFile y la etiquetaError que es a donde saltar si falla
;Modifica los registros de eax y  edx
mAbrirArchivo MACRO funcion, etiquetaError
	mov edx, OFFSET nombreArchivo
	call funcion

	cmp eax, INVALID_HANDLE_VALUE
	je etiquetaError
	mov archivoHandle, eax
ENDM

;mCerrarArchivo cierra el archivo abierto
;Devuelve eax = 0 si fallo
mCerrarArchivo MACRO
	mov eax, archivoHandle
	call CloseFile
ENDM

.data
	;datos y limites
	cantidadProductos DWORD 0
	cambiosSinGuardar DWORD 0
	ventas DWORD 0 ;ingresos totales de la sesion en centavos

	;catalogo con arreglos paralelos
	nombresProductos BYTE limiteProductos * 26 DUP(0)
	codigosProductos BYTE limiteProductos * 8 DUP(0)
	precios DWORD limiteProductos DUP(0) ;precios en centavos
	existencias DWORD limiteProductos DUP(0) ;reserva un espacio DWORD en memoria y lo duplica limiteProductos veces

	;copia temporal de datos del archivo para validar antes de cargarlo
	tempCantidad DWORD 0
	tempCodigos BYTE limiteProductos * 8 DUP(0)
	tempNombres BYTE limiteProductos * 26 DUP(0)
	tempPrecios DWORD limiteProductos DUP(0)
	tempExistencias DWORD limiteProductos DUP(0)

	;buffers para guardar la informacion de forma temporal
	nombreProducto BYTE 81 DUP(0) ;mayor a 26 para detectar entradas largas y poder rechazar el texto
	codigoProducto BYTE 16 DUP(0)
	bufferNumero BYTE 16 DUP(0) ;buffer para guardar de forma temporar datos como el precio, existencia y las cantidades de venta
	bufferSalida BYTE 12 DUP(0) ;texto de un numero o importe antes de imprimirlo (max "42949672.95" + 00h)
	opcion BYTE 16 DUP(0) ;para guardar la opcion ingresada por el usuario
	bufferArchivo BYTE 600 DUP(0) ;texto del archivo, si se tienen 10 lineas de 47 carcateres, da como maximo 470 bytes

	etiquetaMXN BYTE " MXN", 0
	msgUsd BYTE " unidades ", 0

	;datos del menu
	msgMenu BYTE 13, 10, "MENU DE ACCIONES", 13, 10, 0 ;13, 10, indican salto de linea, esto para evitar muchos crlf
	msgAlta BYTE "1. Alta de producto", 13, 10, 0
	msgInventario BYTE "2. Mostrar inventario", 13, 10, 0
	msgBuscar BYTE "3. Buscar producto por codigo", 13, 10, 0
	msgMercancia BYTE "4. Recibir mercancia de un producto", 13, 10, 0
	msgVenta BYTE "5. Realizar venta de producto", 13, 10, 0
	msgResumen BYTE "6. Mostrar resumen", 13, 10, 0
	msgGuardar BYTE "7. Guardar catalogo", 13, 10, 0
	msgCargar BYTE "8. Cargar un archivo de catalogo", 13, 10, 0
	msgSalir BYTE "9. Salir", 13, 10, 0
	msgOpcion BYTE "Elija una opcion: ", 0

	;mensaje de ingreso de datos
	msgIngreso BYTE "Nombre del nuevo producto: ", 0
	msgCodigo BYTE "Codigo del producto (formato ABC-123): ", 0
	msgPrecio BYTE "Precio del producto: ", 0
	msgExistencia BYTE "Existencia del producto: ", 0
	msgBuscarCodigo BYTE "Ingrese el codigo del producto: ", 0
	msgCantMercancia BYTE "Ingrese la cantidad de mercancia a sumar: ", 0
	msgVender BYTE "Ingrese la cantidad de producto a vender: ", 0
	msgSinGuardar BYTE "Hay cambios sin guardar, aun asi desea salir? (1 para si, 2 para no) ", 0

	;mensajes de resultados
	msgExito BYTE "Procedimiento exitoso.", 0
	msgUnidades BYTE "Unidades disponibles: ", 0
	msgValor BYTE "Valor total del inventario: ", 0
	msgVentas BYTE "Ingresos acumulados de la sesion: ", 0
	msgImporte BYTE "Importe de la venta: ", 0
	msgAlerta BYTE "ALERTA: Existencia del producto menor a 10 unidades.", 13, 10, 0

	;mensajes de error
	msgCaractInvalidos BYTE "Caracteres invalidos, vuelva a ingresar la informacion.", 13, 10, 0
	msgPrecioInvalido BYTE "Precio invalido.", 13, 10, 0
	msgLleno BYTE "Inventario lleno.", 13, 10, 0
	msgLimite BYTE "La existencia no se encuentra dentro del limite permitido.", 13, 10, 0
	msgSinProductos BYTE "No hay productos registrados.", 13, 10, 0
	msgNoExistente BYTE "Ese codigo no existe.", 13, 10, 0
	msgDuplicado BYTE "Ese codigo ya se encuentra registrado.", 13, 10, 0
	msgCantidadCero BYTE "La cantidad debe ser mayor que 0.", 13, 10, 0
	msgCantidadInvalida BYTE "La cantidad supera la existencia del producto.", 0
	msgDesbordamiento BYTE "Hubo un desbordamiento. La operacion fue cancelada.", 13, 10, 0
	msgError BYTE "El archivo no se guardo correctamente.", 13, 10, 0
	msgErrorCarga BYTE "No se pudo abrir o leer el archivo. Catalogo sin cambios.", 13, 10, 0
	msgArchivoInvalido BYTE "El archivo esta danado o es invalido. Catalogo sin cambios.", 13, 10, 0

	;datos del archivo
	nombreArchivo BYTE "Catalogo.txt", 0
	archivoHandle DWORD ?

.code
;main solo guarda el menu repetitivo
main PROC
menu:
	mMostrar msgMenu
	mMostrar msgAlta ;1
	mMostrar msgInventario ;2
	mMostrar msgBuscar ;3
	mMostrar msgMercancia ;4
	mMostrar msgVenta ;5
	mMostrar msgResumen ;6
	mMostrar msgGuardar ;7
	mMostrar msgCargar ;8
	mMostrar msgSalir ;9
	mMostrar msgOpcion

	mLeerCadena opcion

	cmp eax, 1
	jne opcionInvalida ;si hay mas de un caracter la opcion es invalida

	mov al, opcion ;guardamos la opcion en el registro al para compararla

	;cada mOpcion compara al con un caracter; si coincide, llama al procedimiento y regresa al menu
	mOpcion '1', altaDeProducto
	mOpcion '2', mostrarInventario
	mOpcion '3', buscarProducto
	mOpcion '4', recibirMercancia
	mOpcion '5', ventaDeProducto
	mOpcion '6', mostrarResumen
	mOpcion '7', guardarCat
	mOpcion '8', cargarCat

	cmp al, '9'
	jne opcionInvalida ;si no se puso ninguna de las opciones anteriores, entonces la opcion es invalida

	cmp cambiosSinGuardar, 0
	je fin ;si no existen cambios sin guardar, se termina el programa

	mMostrar msgSinGuardar ;si no, preguntamos si quiere salir aun asi
	mLeerCadena opcion

	cmp eax, 1 ;revisamos la longitud de la opcion
	jne opcionInvalida

	cmp opcion, '1'
	je fin ;si es 1, se termina el programa

	cmp opcion, '2'
	je menu ;si no quiere salir todavia, vamos de regreso al menu

opcionInvalida:
	mMostrar msgCaractInvalidos
	jmp menu
fin:
	exit
main ENDP

;Procedimientos
;altaDeProducto: registrar productos, capturar datos y rechazarlos si estan incorrectos
;No recibe nada
;Devuelve el producto agregado y el inventario impreso, o un mensaje de error
;Modifica los registros de eax, ebx, ecx, edx, esi y edi
altaDeProducto PROC
	cmp cantidadProductos, limiteProductos
	jae inventarioLleno

	;nombre
	mMostrar msgIngreso
	mLeerCadena nombreProducto

	;verificacion de la longitud del nombre
	cmp eax, 25
	ja caracteresInvalidos

	cmp eax, 1
	jb caracteresInvalidos

	;capturarCodigo pide, valida el formato y lo busca
	mov edx, OFFSET msgCodigo
	call capturarCodigo
	cmp eax, 1
	je fin ;formato incorrecto
	cmp esi, -1
	jne duplicado ;si esi diferente de -1 es porque el codigo ya existe

	;precio en centavos
	mov edx, OFFSET msgPrecio
	call capturarPrecio
	mSiError fin

	mov ebx, cantidadProductos ;ebx = indice del nuevo producto
	mov precios[ebx*4], eax

	;existencia
	mov edx, OFFSET msgExistencia
	call capturarCantidad
	mSiError fin

	cmp eax, 100
	ja superaLimite

	mov existencias[ebx*4], eax
	call alertaExistenciaMinima ;alerta si la existencia es menor a 10

	;si todo esta bien se copia el nombre y el codigo a su lugar
	mDesplazamiento cantidadProductos, 26
	add eax, OFFSET nombresProductos ;eax = direccion donde va el nombre
	mCopiarBytes eax, OFFSET nombreProducto, 26

	mDesplazamiento cantidadProductos, 8
	add eax, OFFSET codigosProductos ;eax = direccion donde va el codigo
	mCopiarBytes eax, OFFSET codigoProducto, 8

	inc cantidadProductos
	mTerminarConExito 1 ;producto registrado con exito
	call mostrarInventario ;mostramos el inventario
	jmp fin

caracteresInvalidos:
	mMostrar msgCaractInvalidos
	jmp fin
duplicado:
	mMostrar msgDuplicado
	jmp fin
inventarioLleno:
	mMostrar msgLleno
	jmp fin
superaLimite:
	mMostrar msgLimite
fin:
	ret
altaDeProducto ENDP

;mostrarInventario: recorre todos los productos con esi
;No recibe nada
;Devuelve el inventario impreso en la consola
;Va a conservar con USES a eax y esi porque tambien lo llama altaDeProducto
mostrarInventario PROC USES eax esi
	call sinProductos ;no hay inventario para mostrar
	cmp eax, 1
	je fin

	mov esi, 0

recorrerInventario:
	call imprimirProductos
	inc esi
	cmp esi, cantidadProductos
	jb recorrerInventario
fin:
	ret
mostrarInventario ENDP

;buscarProducto: valida que tenga el formato, lo busca y muestra el producto
;No recibe nada
;Devuelve el registro de esi = indice del producto encontrado o -1 si hubo algun error
;Va a conservar con USES los registros de eax y edx
buscarProducto PROC USES eax edx
	call sinProductos ;si no hay productos, no hay codigo que buscar
	cmp eax, 1
	je error

	mov edx, OFFSET msgBuscarCodigo
	call capturarCodigo
	cmp eax, 1
	je fin ;formato incorrecto

	cmp esi, -1
	je noExiste

	call imprimirProductos
	jmp fin

noExiste:
	mMostrar msgNoExistente
	jmp fin
error:
	mov esi, -1
fin:
	ret
buscarProducto ENDP

;recibirMercancia: suma unidades a un producto ya existente sin pasar de las 100 unidades
;No recibe nada
;Devuelve la existencia actualizada o un mensaje de error
;Modifica los registros de eax y esi
recibirMercancia PROC
	call buscarProducto
	cmp esi, -1
	je fin ;si el codigo no existe se terminara el proceso

	mov edx, OFFSET msgCantMercancia
	call capturarCantidadPositiva ;rechaza texto invalido y 0
	mSiError fin

	add eax, existencias[esi*4]
	jc superaLimite ;si la suma es mayor a 32 bits es que hay un desbordamiento

	cmp eax, 100
	ja superaLimite

	mov existencias[esi*4], eax ;si la cantidad es valida se actualiza la existencia
	call alertaExistenciaMinima

	mTerminarConExito 1 ;hay cambios sin guardar
	jmp fin

superaLimite:
	mMostrar msgLimite
fin:
	ret
recibirMercancia ENDP

;ventaDeProducto: vender mercancia de un producto y comprobar las existencias
;No recibe nada
;Devuelve la existencia y los ingresos actualizados o el mensaje de error
;Modifica los registros de eax, ebx, ecx y esi
ventaDeProducto PROC
	call buscarProducto
	cmp esi, -1
	je fin

	mov edx, OFFSET msgVender
	call capturarCantidadPositiva
	mSiError fin

	cmp eax, existencias[esi*4]
	ja sinExistencias

	mov ebx, eax ;guarda la cantidad vendida
	call calcularImporte ;eax = cantidad * precio
	mov ecx, eax ;ecx guarda el importe de la venta

	add eax, ventas
	jc desborde
	mov ventas, eax ;se actualizan los datos
	sub existencias[esi*4], ebx ;se resta lo vendido a las existencias

	mMostrarImporte msgImporte, ecx

	mov eax, existencias[esi*4]
	call alertaExistenciaMinima

	mTerminarConExito 1
	jmp fin

sinExistencias:
	mMostrar msgCantidadInvalida
	jmp fin
desborde:
	mMostrar msgDesbordamiento
fin:
	ret
ventaDeProducto ENDP

;mostrarResumen: recorre todos los productos con esi, calcula las unidades disponibles y el valor del inventario
;No recibe nada
;Devuelve los ingresos de la sesion. las unidades disponibles y el valor del inventario
;Modifica los registros de eax, ebx, ecx, esi y edi
mostrarResumen PROC
	mov ebx, 0 ;guardara las unidades disponibles
	mov esi, 0 ;indice del producto
	mov edi, 0 ;guardara el valor del inventario en centavos
	mov ecx, cantidadProductos
	jecxz mostrarTotales ;se salta el ciclo y los totales quedan en 0

ciclo:
	mov eax, existencias[esi*4]
	add ebx, eax
	call calcularImporte ;eax = existencia * precio
	add edi, eax

	inc esi
	loop ciclo

mostrarTotales:
	mMostrar msgUnidades
	mov eax, ebx
	call decimalATexto
	call crlf

	mMostrarImporte msgValor, edi
	mMostrarImporte msgVentas, ventas
	ret
mostrarResumen ENDP

;guardarCat: guarda el catalogo con codigo, precio, existencia, nombre
;primero arma todo el texto en bufferArchivo y despues lo escribe todo de una
;No recibe nada
;Devuelve el archivo Catalogo.txt guardado o el mensaje de error
;Modifica los registros de eax, ebx, ecx, edx, esi y edi
guardarCat PROC
	;arma el archivo en memoria
	mov edi, OFFSET bufferArchivo ;en edi se va a escribir el siguiente caracter
	mov esi, 0 ;esi sera el indice del producto

siguienteLinea:
	cmp esi, cantidadProductos
	jae textoListo ;se escribieron todos los productos

	;codigo de 7 caracteres
	mDesplazamiento esi, 8
	add eax, OFFSET codigosProductos
	mCopiarBytes edi, eax, 7
	add edi, 7
	mPonerCaracter ','

	;precio en pesos, el punto y dos decimales
	mov eax, precios[esi*4]
	call centavosATexto
	mPonerCaracter ','

	;existencia
	mov eax, existencias[esi*4]
	call numeroATexto
	mPonerCaracter ','

	;nombre
	mDesplazamiento esi, 26
	mov ebx, eax

copiarNombreArchivo:
	mov al, nombresProductos[ebx]
	cmp al, 0
	je finLinea

	mov [edi], al
	inc ebx
	inc edi
	jmp copiarNombreArchivo

finLinea:
	;se hace el salto de linea
	mPonerCaracter 13
	mPonerCaracter 10

	inc esi ;elsiguiente producto
	jmp siguienteLinea

textoListo:
	mAbrirArchivo CreateOutputFile, error ;crear el archivo

	;se escribe todo el texto
	mov edx, OFFSET bufferArchivo
	mov ecx, edi
	sub ecx, OFFSET bufferArchivo
	call escribirBloque
	cmp eax, 1
	je errorEscritura

	mCerrarArchivo ;cerrar archivo txt
	cmp eax, 0
	je error

	mTerminarConExito 0
	jmp fin

errorEscritura:
	mCerrarArchivo
error:
	mMostrar msgError
fin:
	ret
guardarCat ENDP

;cargarCat: lee el archivo de texto, lo convierte a la copia temporal, lo valida y lo carga
;No recive nada
;Devuelve el catalogo y cambiosSinGuardar = 0
;Modifica los registros de eax, ebx, ecx y edx
cargarCat PROC
	mAbrirArchivo OpenInputFile, errorAbrir ;abrir el archivo

	;Se lee todo el archivo
	mov edx, OFFSET bufferArchivo
	mov ecx, SIZEOF bufferArchivo - 1
	call ReadFromFile
	jc errorLectura

	mov ebx, eax ;se guardan los bytes leidos en el ebx

	mCerrarArchivo
	cmp eax, 0
	je errorAbrir

	cmp ebx, SIZEOF bufferArchivo - 1
	jae archivoInvalido ;el archivo es muy grande si salta

	mov bufferArchivo[ebx], 0 ;se agrega el terminador nulo

	call convertirTexto ;pasa el texto a la copia temporal
	cmp eax, 1
	je archivoInvalido

	call validarCatalogo
	cmp eax, 1
	je archivoInvalido

	;se copia la copia temporal al catalogo real
	mov eax, tempCantidad
	mov cantidadProductos, eax
	mCopiarBytes OFFSET codigosProductos, OFFSET tempCodigos, SIZEOF codigosProductos
	mCopiarBytes OFFSET nombresProductos, OFFSET tempNombres, SIZEOF nombresProductos
	mCopiarBytes OFFSET precios, OFFSET tempPrecios, SIZEOF precios
	mCopiarBytes OFFSET existencias, OFFSET tempExistencias, SIZEOF existencias

	mTerminarConExito 0
	jmp fin

errorLectura:
	mCerrarArchivo
archivoInvalido:
	mMostrar msgArchivoInvalido
	jmp fin
errorAbrir:
	mMostrar msgErrorCarga
fin:
	ret
cargarCat ENDP

;capturarCodigo: pide un codigo, lo lee, valida el formato y lo busca en el catalogo
;Recibe a edx = offset del mensaje que se muestra antes de leer
;Devuelve los registros de eax = 0/1. esi = indice del producto o -1 y codigoProducto = codigo leido
;Conserva usando USES los registros de ecx, edx, edi
capturarCodigo PROC USES ecx edx edi
	call WriteString
	mLeerCadena codigoProducto

	mov edi, OFFSET codigoProducto
	call verificarCodigoProducto
	cmp eax, 1
	je invalido

	call localizarCodigo
	jmp fin

invalido:
	mMostrar msgCaractInvalidos
	mov esi, -1
fin:
	ret
capturarCodigo ENDP

;capturarCantidad: pide una cantidad entera la lee de bufferNumero y la convierte
;Recibe a edx = offset del mensaje que se muestra antes de leer
;Devuelve el registro de eax = cantida o -1
capturarCantidad PROC USES ecx edx
	call WriteString
	mLeerCadena bufferNumero

	call textoADecimal
	cmp eax, -1
	jne fin

	mMostrar msgCaractInvalidos
fin:
	ret
capturarCantidad ENDP

;capturarCantidadPositiva: rechaza el 0 para la mercancia y ventas
;Recibe a edx = offset del mensaje
;Devuelve a eax cantidad mayor que 0 o -1 si es invalida
capturarCantidadPositiva PROC
	call capturarCantidad
	cmp eax, 0
	jne fin ;si es -1 o una cantidad mayor que 0

	mMostrar msgCantidadCero
	mov eax, -1
fin:
	ret
capturarCantidadPositiva ENDP

;capturarPrecio: pide el precio que lo lee de bufferNumero y lo convierte a centavos
;Recibe a edx = offset del mensaje
;Devuelve a eax = precio en centavos o -1
;Conserva con USES a los registrso de ecx, edx
capturarPrecio PROC USES ecx edx
	call WriteString
	mLeerCadena bufferNumero

	call textoACentavos
	cmp eax, -1
	jne fin

	mMostrar msgPrecioInvalido
fin:
	ret
capturarPrecio ENDP

;localizarCodigo: recorre el catalogo con esi y compara cada codigo con codigoProducto
;Recibe codigoProducto
;Devuelve a esi = indice del producto encontrado o -1 
localizarCodigo PROC USES eax ebx edx edi
	mov esi, 0

siguienteProducto:
	cmp esi, cantidadProductos
	jae noEncontrado

	mDesplazamiento esi, 8
	mov edi, OFFSET codigosProductos
	add edi, eax ;edi = codigo del producto actual
	mov edx, OFFSET codigoProducto
	call codigosIguales
	cmp eax, 1
	je fin ;si se encuentra

	inc esi
	jmp siguienteProducto

noEncontrado:
	mov esi, -1
fin:
	ret
localizarCodigo ENDP

;codigosIguales: compara los 7 caracteres de dos codigos
;Recibe a edx = direccion del primer codigo y a edi = direccion del segundo codigo
;Devuelve a eax = 1 si son iguales o 0 si estos son distintos
;Conserva con USES los registros de ebx, ecx, edx, edi
codigosIguales PROC USES ebx ecx edx edi
	mov ecx, 7

comparar:
	mov bl, [edx]
	cmp bl, [edi]
	jne distintos

	inc edx
	inc edi
	loop comparar

	mov eax, 1
	ret

distintos:
	mov eax, 0
	ret
codigosIguales ENDP

;calcularImporte: calcula un importe de cantidad * precio
;Recibe a eax = cantidad y esi = indice del producto
;Devuelve a eax = importe en centavos
calcularImporte PROC USES edx
	mul precios[esi*4]
	ret
calcularImporte ENDP

;escribirBloque: escribe un bloque de bytes en el archivo abierto y comprueba que se hayan escrito todos
;Recibe a edx con la direccion del texto y a ecx con los bytes a escribir
;Devuelve a eax = 0 o 1
escribirBloque PROC USES ebx
	mov ebx, ecx ;cantidad de bytes pedidos
	mov eax, archivoHandle
	call WriteToFile

	cmp eax, ebx
	jne error

	mov eax, 0
	jmp fin

error:
	mov eax, 1
fin:
	ret
escribirBloque ENDP

;convertirTexto: recorre a bufferArchivo con esi linea por linea y lo convierte a la copia temporal
;Recibe a bufferArchivo
;Devuelve a eax = 0 o 1 si es incorrecto
convertirTexto PROC USES ebx ecx edx esi
	mov tempCantidad, 0
	mov esi, OFFSET bufferArchivo ;esi recorre el texto caracter por caracter

siguienteLinea:
	mov al, [esi]
	cmp al, 0
	je textoValido ;se llego al final del texto

	cmp al, 13 ;se ignoran los saltos de linea y las lineas vacias
	je saltar

	cmp al, 10
	je saltar

	cmp tempCantidad, limiteProductos
	jae textoInvalido ;mas de 10 productos

	mDesplazamiento tempCantidad, 8
	mov ebx, eax
	mov ecx, 7

copiarCodigoTemp:
	mov al, [esi]
	cmp al, 0
	je textoInvalido ;el texto se acabo antes de tiempo

	mov tempCodigos[ebx], al
	inc esi
	inc ebx
	loop copiarCodigoTemp

	mov tempCodigos[ebx], 0 ;terminador nulo

	mov al, [esi]
	cmp al, ','
	jne textoInvalido
	inc esi ;se slata la coma

	;precio
	call leerCampo
	mSiError textoInvalido
	call textoACentavos
	mSiError textoInvalido

	mov ebx, tempCantidad
	mov tempPrecios[ebx*4], eax

	;existencia
	call leerCampo
	mSiError textoInvalido
	call textoADecimal
	mSiError textoInvalido

	mov ebx, tempCantidad
	mov tempExistencias[ebx*4], eax

	;nombre
	mDesplazamiento tempCantidad, 26
	mov ebx, eax
	mov ecx, 0

copiarNombreTemp:
	mov al, [esi]
	cmp al, 13
	je finNombre

	cmp al, 10
	je finNombre

	cmp al, 0
	je finNombre

	cmp ecx, 25
	jae textoInvalido ;tiene mas de 25 caracteres el nombre

	mov tempNombres[ebx + ecx], al

	inc esi
	inc ecx
	jmp copiarNombreTemp

finNombre:
	mov tempNombres[ebx + ecx], 0 ;terminador nulo al final
	inc tempCantidad
	jmp siguienteLinea
saltar:
	inc esi
	jmp siguienteLinea
textoValido:
	mov eax, 0
	jmp fin
textoInvalido:
	mov eax, 1
fin:
	ret
convertirTexto ENDP

;leerCampo: mide un campodel archivo hasta encontrar la coma y la salta, si no hay coma es invalido
;Recibe a esi como el inicio del campo
;Devuelve a edx = inicio del campo. eax = longitud o -1 y a esi = caracter siguiente a la coma
leerCampo PROC
	mov edx, esi ;se guarda en donde comienza el campo

contar:
	mov al, [esi]
	cmp al, ','
	je finCampo
	cmp al, 13
	je sinComa
	cmp al, 10
	je sinComa
	cmp al, 0
	je sinComa
	inc esi
	jmp contar

finCampo:
	mov eax, esi
	sub eax, edx ;longitud
	inc esi ;salta la coma
	ret

sinComa:
	mov eax, -1
	ret
leerCampo ENDP

;validarCatalogo: valida la copia temporal leida del archivo
;Recibe a tempCantidad, tempCodigos, tempNombres, tempPrecios y tempExistencias
;Devuelve el registro de eax = 0 si es valido o eax = 1 si no
validarCatalogo PROC USES ebx ecx edx esi edi
	cmp tempCantidad, limiteProductos
	ja invalido

	mov esi, 0

siguienteProducto:
	cmp esi, tempCantidad
	jae valido

	;codigo
	mDesplazamiento esi, 8
	mov edi, OFFSET tempCodigos
	add edi, eax ;codigo del producto actual
	call verificarCodigoProducto
	cmp eax, 1
	je invalido

	;que no se repita con los productos anteriores
	mov ecx, 0 ;indice del producto anterior

anterior:
	cmp ecx, esi
	jae nombre

	mDesplazamiento ecx, 8
	mov edx, OFFSET tempCodigos
	add edx, eax ;codigo del producto anterior
	call codigosIguales
	cmp eax, 1
	je invalido ;codigo repetido

	inc ecx
	jmp anterior

nombre:
	mDesplazamiento esi, 26
	mov edi, eax ;desplazar el nombre
	cmp tempNombres[edi], 0
	je invalido

	mov ecx, 26
	mov ebx, 0

buscarFinNombre:
	cmp tempNombres[edi + ebx], 0
	je nombreCorrecto

	inc ebx

	loop buscarFinNombre
	jmp invalido

nombreCorrecto:
	;precio y existencia
	mov eax, tempPrecios[esi*4]
	cmp eax, 1
	jb invalido

	cmp eax, 999999
	ja invalido

	mov eax, tempExistencias[esi*4]
	cmp eax, 100
	ja invalido

	inc esi
	jmp siguienteProducto

valido:
	mov eax, 0
	ret
invalido:
	mov eax, 1
	ret
validarCatalogo ENDP

;verificarCodigoProducto: verifica que se cumpla el formato del codigo ABC-123
;Recibe a edi = direccion del codigo
;Devuelve a eax = 0 si es valido y eax = 1 si no
verificarCodigoProducto PROC USES ebx
	mov ebx, 0

verificacionLetras:
	mov al, [edi + ebx]

	cmp al, 'A'
	jb caracteresInvalidos

	cmp al, 'Z'
	ja caracteresInvalidos

	inc ebx

	cmp ebx, 3
	jb verificacionLetras

	mov al, [edi + ebx]
	cmp al, '-'
	jne caracteresInvalidos
	inc ebx

verificacionNumeros:
	mov al, [edi + ebx]

	cmp al, '0'
	jb caracteresInvalidos
	cmp al, '9'
	ja caracteresInvalidos

	inc ebx

	cmp ebx, 7
	jb verificacionNumeros

	mov al, [edi + ebx] ;no puede haber un octavo caracter
	cmp al, 0
	jne caracteresInvalidos

	mov eax, 0
	jmp fin

caracteresInvalidos:
	mov eax, 1
fin:
	ret
verificarCodigoProducto ENDP

;sinProductos: verifica si el catalogo esta vacio
;Devuelve eax = 1 si no hay productos o eax = 0 si hay
sinProductos PROC
	cmp cantidadProductos, 0
	jne hayProductos

	mMostrar msgSinProductos

	mov eax, 1
	jmp fin
hayProductos:
	mov eax, 0
fin:
	ret
sinProductos ENDP

;textoADecimal: convierte un texto a numero
;Recibe edx = direccion del texto y a eax = longitud
;Devuelve eax = valor o -1 si es invalido
textoADecimal PROC USES ebx ecx edx esi
	mov esi, edx ;puntero de la cadena
	mov ecx, eax ;los caracteres que faltan por convertir
	mov eax, 0 ;el acumulado

	cmp ecx, 0
	je invalido

siguiente:
	mov ebx, 0
	mov bl, [esi]

	sub bl, '0' ;para convertirlos a decimal

	cmp bl, 9
	ja invalido

	mov edx, 10
	mul edx
	jc invalido ;da error si la multiplicacion se paso de 32 bits

	add eax, ebx
	jc invalido

	inc esi
	loop siguiente

	jmp fin
invalido:
	mov eax, -1
fin:
	ret
textoADecimal ENDP

;textoACentavos: convierte un precio en texto a centavos enteros
;Recibe a edx = direccion del texto y eax = longitud
;Devuelve a eax = valor en centavos o -1 si es invalido
textoACentavos PROC USES ebx ecx edx esi edi
	mov esi, edx ;el puntero de la cadena
	mov ecx, eax
	mov eax, 0
	mov edi, -1 ;decimales leidos

	cmp ecx, 0
	je invalido

	mov bl, [esi]
	cmp bl, '.' ;es invalido si el primero es un punto
	je invalido

siguiente:
	mov ebx, 0
	mov bl, [esi]
	cmp bl, '.'
	je punto

	sub bl, '0'
	cmp bl, 9
	ja invalido

	mov edx, 10
	mul edx

	add eax, ebx
	cmp eax, 999999 ;revisa desborde
	ja invalido

	cmp edi, -1
	je avanzar

	inc edi

	cmp edi, 2 ;si ya es decimal de mas de dos giditos
	ja invalido

	jmp avanzar

punto:
	cmp edi, -1
	jne invalido ;no puede haber otro punto
	mov edi, 0

avanzar:
	inc esi
	loop siguiente

	cmp edi, 0
	je invalido

	cmp edi, -1
	je sinPunto

	cmp edi, 1
	je unDecimal

	jmp rango
sinPunto:
	mov edx, 100
	mul edx

	jmp rango
unDecimal:
	mov edx, 10
	mul edx
rango:
	cmp eax, 1
	jb invalido

	cmp eax, 999999
	ja invalido

	jmp fin
invalido:
	mov eax, -1
fin:
	ret
textoACentavos ENDP

;numeroATexto: convierte el numero de eax a digitos ASCII y los escribe
;Recibe a eax = numero sin signo y edi = destino
;Devuelve a edi
numeroATexto PROC USES eax ebx ecx edx
	mov ebx, 10
	mov ecx, 0 ;se cuentan los digitos

dividir:
	mov edx, 0
	div ebx
	push edx
	inc ecx
	cmp eax, 0
	jne dividir

escribirDigito:
	pop eax
	add al, '0'
	mov [edi], al
	inc edi
	loop escribirDigito

	ret
numeroATexto ENDP

;centavosATexto: convierte centavos a texto
;Recibe a eax = cantidad en centavos y edi = destino
;Devuelve a edi
centavosATexto PROC USES eax ebx edx
	mov ebx, 100
	mov edx, 0
	div ebx ;eax = pesos y edx = centavos

	call numeroATexto ;escribe los pesos
	mPonerCaracter '.'

	cmp edx, 10
	jae dosDigitos
	mPonerCaracter '0'

dosDigitos:
	mov eax, edx
	call numeroATexto ;escribe los centavos
	ret
centavosATexto ENDP

;decimalATexto: imprime un entero sin signo
;Recibe a eax con el numero
decimalATexto PROC USES eax edi
	mov edi, OFFSET bufferSalida
	call numeroATexto
	mPonerCaracter 0
	mMostrar bufferSalida
	ret
decimalATexto ENDP

;imprimirDinero: muestra un importe en centavos como pesos
;Recibe a eax = importe en centavos
imprimirDinero PROC USES eax edi
	mov edi, OFFSET bufferSalida
	call centavosATexto
	mPonerCaracter 0
	mMostrar bufferSalida
	mMostrar etiquetaMXN
	call crlf
	ret
imprimirDinero ENDP

;imprimirProductos: imprime un producto en una linea
;Recibe a ESI = indice del producto
imprimirProductos PROC USES eax ebx edx
	;codigo
	mDesplazamiento esi, 8
	mov edx, OFFSET codigosProductos
	add edx, eax ;para indicarle a edx cual es el codigo a imprimir
	call WriteString

	mov al, ' '
	call WriteChar

	;nombre
	mDesplazamiento esi, 26
	mov edx, OFFSET nombresProductos
	add edx, eax
	call WriteString

	mov al, ' '
	call WriteChar

	mov eax, existencias[esi*4] ;existencia
	call decimalATexto
	mMostrar msgUsd

	mov eax, precios[esi*4] ;precio
	call imprimirDinero
	ret
imprimirProductos ENDP

;mensajeExito: muestra el mensaje de Procedimiento exitoso.
;No modifica registros
mensajeExito PROC
	mMostrar msgExito
	call crlf
	ret
mensajeExito ENDP

;alertaExistenciaMinima: dice si la existencia de un producto es menor a 10 unidades
;Recibe a eax como la existencia
;No modifica los registros
alertaExistenciaMinima PROC
	cmp eax, 10
	jae fin

	mMostrar msgAlerta
fin:
	ret
alertaExistenciaMinima ENDP
END main