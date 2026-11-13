Plan de verificación: UART 16550

Llenen todas las tablas. Las filas en gris son ejemplos que muestran el nivel de detalle esperado: reemplácenlas por las suyas. Pueden agregar filas y secciones, pero no eliminar ninguna.

# Portada

|Campo|Valor|
|---|---|
|Proyecto|Verificación del UART 16550 con UVM|
|Integrante 1|Luis Diego García Rojas|
|Integrante 2|Eric Jossué Castro Velásquez|
|Integrante 3|Randy Steve Fernández Aguilar|
|Versión del plan|v1|
|Fecha|29 de octubre del 2026|
|Repositorio Git|https://github.com/Scrys26/Proyecto2-SystemVerilog-Verification-|
|Etiqueta Git|N/A|

# 1. Alcance

|Campo|Valor|
|---|---|
|Versión del RTL verificada (commit o revisión SVN)|N/A|
|Configuración de compilación (bus de 32 bits; variante de 8 bits sí/no)|bus de 32 bits|
|Frecuencia de reloj en simulación y rango de DL soportado|Reloj: **por decidir** (un valor fijo de simulación, que ya está en su lista de “fijo”). DL de 16 bits: **0 a 65535**. DL = 0 es legal (no transmite ni recibe),|
|Funcionalidad fuera de alcance y justificación|Aspectos eléctricos y físicos: el RTL simulado es digital e ideal.|

# 2. Documentos de referencia

|Documento|Versión|Enlace o ubicación|
|---|---|---|
|UART IP Core Specification|Rev. 0.6|doc/UART_spec.pdf|

# 3. Interpretación de la especificación

Una fila por cada ambigüedad o discrepancia entre la especificación y el RTL (sección 3.5 del enunciado).

|ID|Tema|La especificación dice|El RTL hace|Comportamiento que modelamos|Justificación|
|---|---|---|---|---|---|
|AMB-01|Registro scratch (dir. 7)|Fue removido|uart_regs.v lo implementa en la dirección 7: lectura y escritura, reset en 0|Registro RW de 8 bits, reset 8'h00. Se anota como funcionalidad del RTL no exigida por la especificación|La especificación está desactualizada. Se documenta la diferencia y se verifica su funcionamiento|
|AMB-02|wb_sel_i en modo de 32 bits|Solo indica que selecciona el byte; no define varios bits activos|uart_wb.v usa selección one-hot. En escritura, una combinación no reconocida usa los bits [7:0] y la dirección 0. En lectura devuelve 0, salvo 1111, que se usa para depuración|One-hot para accesos de 8 bits y 1111 para lecturas de depuración de 32 bits. Las demás combinaciones se clasifican como comportamiento no especificado|No se asume un resultado funcional para lo que la especificación no define. Se documenta lo que hace el RTL|
|AMB-03|Bits de parada 1.5 y 2|1.5 con 5 bits y 2 en los demás. El receptor revisa solo el primero|El transmisor tiene lógica para las tres duraciones y el receptor comprueba un solo bit de parada. El historial de 2001 dice que más de uno no estaba implementado|Se prueban las tres duraciones en TX y su duración se mide. En RX se valida solo el primer bit de parada|La nota de 2001 corresponde a una versión anterior. La duración exacta se confirma por simulación|
|AMB-04|Polaridad de RTS y DTR|Las salidas de módem son activas en bajo|En uart_reg.sv, RTS y DTR se asignan directamente desde los bits correspondientes de MCR.|Se comprueban los niveles físicos que genera el RTL y se documenta su diferencia respecto a la especificación.|La diferencia puede afectar la comprobación de las salidas del módem. Se confirmará durante la simulación.|

# 4. Lista de características

|ID|Característica|Fuente (sección de la especificación)|Prioridad (alta, media, baja)|
|---|---|---|---|
|F-LCR-01|Longitud de carácter de 5, 6, 7 y 8 bits|Line Control Register, bits 1:0|Alta|
|F-LCR-02|Formato de línea: paridad y bits de parada y control de break|4.5 (LCR, bits 5:2)|Alta|
|F-DIV-01|Baudrate mediante el divisor DL (16 bits)|4.9|Alta|
|F-TX-01|Transmisión: THR > FIFO > línea serie e indicadores THRE y TEMT|4.1, 4.7|Alta|
|F-RX-01|Recepción: línea serie > FIFO > RBR incluye tolerancia al desajuste de baudrate (revisar tolerancia)|4.1, 4.7|Alta|
|F-FIFO-01|Niveles de disparo de la FIFO de recepción (1, 4, 8, 14)|4.4|Alta|
|F-FIFO-02|Limpieza de las FIFOs de RX y TX por FCR (el registro de desplazamiento sigue su curso)|4.4|Alta|
|F-ERR-01|Errores en recepción: paridad, trama, *break* y *overrun*|4.7|Alta|
|F-INT-01|Interrupciones con prioridad e identificación (IER, IIR) e int_o|4.2, 4.3|Alta|
|F-INT-02|Interrupción de timeout tras 4 tiempos de carácter|Interrupt Identification Register|Alta|
|F-MOD-01|Señales de módem con detección de cambios (MCR, MSR)|4.6, 4.8|Alta|
|F-LB-01|Modo *loopback*|4.6|Alta|
|F-REG-01|Acceso a registros: dirección compartida por DLAB y lecturas que limpian bits|4.1, 4.7, 4.8|Alta|
|F-REG-02|Registros Debug 1 y Debug 2 (solo lectura, solo en modo de 32 bits)|4.10, 4.11|Baja|
|F-RST-01|Reset incluye valores de reset de los registros|5.1|Alta|
|F-WB-01|Protocolo Wishbone esclavo: ciclos simples, ack y selección de byte con wb_sel_i|2.1, 5|Alta|

# 5. Matriz de verificación

Una o más filas por cada característica de la sección 4.

|ID ítem|Característica|Qué se verifica|Mecanismo (scoreboard, SVA, RAL, cobertura)|Métrica de cierre (coverpoint o aserción)|Plusargs que lo dirigen|
|---|---|---|---|---|---|
|V-LCR-01|F-LCR-01|Datos TX y RX correctos con cada longitud|Scoreboard TX y RX|cg_line_cfg.cp_wls × cp_dir|+UART_LCR_WLS_WEIGHTS|
|V-LCR-02|F-LCR-02|Datos y bit de paridad correctos con cada tipo de paridad y cada cantidad de bits de parada|Scoreboard TX y RX|cg_line_cfg.cp_parity × cp_stop × cp_wls|+UART_LCR_PARITY_WEIGHTS, +UART_LCR_STOP_WEIGHTS|
|V-LCR-03|F-LCR-02|Con break activo, stx_pad_o se mantiene en 0 y vuelve a 1 al desactivarlo|SVA y scoreboard|cg_line_cfg.cp_tx_break|+UART_TX_BREAK_PCT|
|V-DIV-01|F-DIV-01|El ancho de bit en la línea serie coincide con 16 × DL ciclos de reloj|SVA del protocolo serie|cg_div.cp_dl (zona rápida, cola)|+UART_DL_MAX_FAST, +UART_DL_MAX, +UART_DL_TAIL_PCT|
|V-DIV-02|F-DIV-01|Con DL = 0 no hay TX ni RX|Scoreboard y SVA|cg_div.cp_dl[0]|+UART_DL_ZERO_PCT|
|V-TX-01|F-TX-01|Lo escrito en THR sale por stx_pad_o en el mismo orden y sin pérdidas|Scoreboard TX|cg_traffic.cp_burst_len|+UART_TX_PAYLOAD_MAX, +UART_TX_PAYLOAD_TAIL_PCT|
|V-TX-02|F-TX-01|Los bits THRE y TEMT de LSR reflejan FIFO vacía y registro de desplazamiento vacío|Scoreboard (LSR)|cg_traffic.cp_thre, cp_temt|+UART_TX_PAYLOAD_MAX|
|V-TX-03|F-TX-01|Se verifica el llenado de la FIFO TX y su comportamiento cuando se intenta escribir un nuevo dato estando llena.|Scoreboard y cobertura|cg_traffic.cp_fifo_level[FULL], cp_tx_write_full|+UART_TX_PAYLOAD_MAX, +UART_WB_DELAY_MAX|
|V-RX-01|F-RX-01|Lo recibido por srx_pad_i llega a RBR en orden, con DR correcto|Scoreboard RX|cg_traffic.cp_rx_len, cp_dr|+UART_SER_PAYLOAD_MAX, +UART_SER_DELAY_MAX|
|V-RX-02|F-RX-01|Recepción correcta del baudrate|Scoreboard RX|cg_traffic.cp_baud_dev[IN, OUT]|+UART_SER_BAUD_DEV_MAX|
|V-FIFO-01|F-FIFO-01|La interrupción de datos disponibles sube exactamente al nivel de disparo configurado|Modelo de interrupciones|cg_fifo.cp_tl × cp_rx_level|+UART_FCR_TL_WEIGHTS|
|V-FIFO-02|F-FIFO-02|Limpiar FIFO RX o TX la vacía y el carácter en el registro de desplazamiento sigue su curso|Scoreboard y RAL|cg_fifo.cp_clear_rx, cp_clear_tx|+UART_FCR_CLEAR_PCT|
|V-ERR-01|F-ERR-01|Errores de paridad, trama y break aparecen en LSR y se limpian al leerlo|Scoreboard (LSR)|cg_err.cp_pe, cp_fe, cp_bi|+UART_SER_PARITY_ERR_PCT, +UART_SER_FRAME_ERR_PCT, +UART_SER_BREAK_PCT, +UART_SER_GLITCH_PCT|
|V-ERR-02|F-ERR-01|Overrun: El contador de la fifo se conserva y se activa OE|Scoreboard (LSR)|cg_err.cp_oe × cp_tl|+UART_SW_SERVICE_DELAY_MAX, +UART_FCR_TL_WEIGHTS|
|V-INT-01|F-INT-01|IIR indica la interrupción de mayor prioridad entre las pendientes|Modelo de interrupciones|cg_int.cp_iir_id × cp_ier|+UART_IER_WEIGHTS|
|V-INT-02|F-INT-01|int_o es coherente con IER e IIR[0]|SVA y scoreboard|cg_int.cp_int_o × cp_ier|+UART_IER_WEIGHTS, +UART_SW_IGNORE_PCT|
|V-INT-03|F-INT-02|IIR [3:0] = 4'hC cuando ocurre un timeout de recepción.|Modelo de interrupciones y scoreboard|cg_int.cp_iir_id[TIMEOUT]|+UART_SW_SERVICE_DELAY_MAX|
|V-MOD-01|F-MOD-01|MSR refleja las entradas de módem y las salidas RTS y DTR siguen al MCR|Scoreboard (MSR)|cg_modem.cp_msr_state, cp_mcr_out|+UART_MODEM_DELAY_MAX, +UART_MCR_WEIGHTS|
|V-MOD-02|F-MOD-01|Bits delta de MSR, verifica si se detectan los cambios activando el delta. Se borran al leer por frontdoor por WB|Scoreboard e interrupciones|cg_modem.cp_delta × cp_signal|+UART_MODEM_DELAY_MAX, +UART_MODEM_CHANGE_PCT|
|V-LB-01|F-LB-01|En loopback lo transmitido se recibe, las salidas de MCR se ven en MSR y stx_pad_o queda en 1|Scoreboard y SVA|cg_modem.cp_lb_en × cp_mcr_out|+UART_MCR_LOOPBACK_PCT|
|V-REG-01|F-REG-01|Registros con dirección compartida acceden al correcto según DLAB|RAL|cg_reg_rst.cp_addr × cp_dlab|+UART_REG_ACCESS_COUNT, +UART_REG_DLAB_PCT|
|V-REG-02|F-REG-01|Lecturas con efectos laterales (LSR, MSR, IIR, RBR) actualizan el modelo|RAL con predictor y scoreboard|cg_reg_rst.cp_side_effect|+UART_REG_ACCESS_COUNT|
|V-REG-03|F-REG-01|Escritura por puerta delantera llega al registro interno (puerta trasera)|RAL (secuencias integradas)|cg_reg_rst.cp_reg_access|+UART_REG_BITBASH_EN, +UART_REG_ACCESS_EN|
|V-REG-04|F-REG-02|Debug 1 y Debug 2 reflejan los valores de los registros y no alteran el estado|RAL y scoreboard|cg_reg_rst.cp_debug_read|+UART_REG_ACCESS_COUNT|
|V-RST-01|F-RST-01|Tras el reset los registros tienen sus valores iniciales y las FIFOs quedan vacías|RAL (uvm_reg_hw_reset_seq)|uvm_reg_hw_reset_seq|ninguno, siempre activo|
|V-RST-02|F-RST-01|Reset asíncrono a mitad de tráfico: el UART vuelve a un estado limpio|Scoreboard, SVA y RAL|cg_reg_rst.cp_reset_state|+UART_RST_EN, +UART_RST_PCT|
|V-WB-01|F-WB-01|Estabilidad de señales mientras cyc && stb sin ack, ack acotado y sin X|SVA|cg_traffic.cp_wb_sel × cp_addr|+UART_WB_DELAY_MAX|
|V-WB-02|F-WB-01|Lectura y escritura correctas con cada valor legal de wb_sel_i|Scoreboard|cg_traffic.cp_wb_sel × cp_addr|+UART_WB_SEL_WEIGHTS|

```
Overrun:
El contador de la fifo se conserva y se activa OE
```

# 6. Estrategia de estímulo: prueba base

## 6.1 Espacio de aleatorización

|Variable aleatoria|Objeto de configuración|Rango legal|Distribución por defecto|Knobs|
|---|---|---|---|---|
|char_length (LCR[1:0])|uart_ser_agent_cfg|5 a 8 bits|Uniforme|LCR_WLS_WEIGHTS|
|stop_bit (LCR[2])|uart_ser_agent_cfg|1 o 2 (1.5 con 5 bits)|Uniforme|LCR_STOP_WEIGHTS|
|parity y parity_type (LCR[5:3])|uart_ser_agent_cfg|Sin paridad, impar, par, stick 1, stick 0|Uniforme entre los 5 casos|LCR_PARITY_WEIGHTS|
|dl (divisor)|uart_ser_agent_cfg|0 a 65535|1 % en DL = 0, 97 % en 1 a 16, 2 % en 17 a 65535|DL_ZERO_PCT, DL_MAX_FAST, DL_MAX, DL_TAIL_PCT|
|fifo_trigger (FCR[7:6])|uart_ser_agent_cfg|1, 4, 8, 14|Uniforme|FCR_TL_WEIGHTS|
|fifo_clear (FCR[2:1])|uart_ser_agent_cfg|0 o 1 por FIFO|10 % de limpiar|FCR_CLEAR_PCT|
|ier_bits (IER[3:0])|modem_agent_cfg|4 bits, 0 o 1|Cada bit 50 %|IER_WEIGHTS|
|loopback_en|modem_agent_cfg|0 o 1|20 % en loopback|MCR_LOOPBACK_PCT|
|mcr_out (DTR, RTS, OUT1, OUT2)|modem_agent_cfg|4 bits, 0 o 1|Cada bit 50 %|MCR_WEIGHTS|
|notification_mode|uart_env_cfg|POLLING, INTERRUPT, MIXED|Uniforme|SW_MODE_WEIGHTS|
|tx_payload_size|uart_ser_agent_cfg|1 a 256|98 % en 1 a 32, 2 % en 33 a 256|TX_PAYLOAD_MAX, TX_PAYLOAD_TAIL_PCT|
|tx_data_byte|uart_ser_agent_cfg|0x00 a 0xFF|Uniforme|(ninguno)|
|wb_delay|wb_agent_cfg|0 a 1000 ciclos|98 % en 0 a 20, 2 % en la cola|WB_DELAY_MAX, WB_DELAY_TAIL_PCT|
|tx_break_pct|uart_ser_agent_cfg|0 a 100|3|TX_BREAK_PCT|
|rx_payload_size|uart_ser_agent_cfg|1 a 256|98 % en 1 a 32, 2 % en 33 a 256|SER_PAYLOAD_MAX, SER_PAYLOAD_TAIL_PCT|
|rx_data_byte|uart_ser_agent_cfg|0x00 a 0xFF|Uniforme|(ninguno)|
|serial_delay|uart_ser_agent_cfg|0 a 1000 bit-times|98 % en 0 a 20, 2 % en la cola|SER_DELAY_MAX, SER_DELAY_TAIL_PCT|
|parity_err_pct, frame_err_pct, rx_break_pct, glitch_pct|uart_ser_agent_cfg|0 a 100|5, 5, 2, 3|SER_PARITY_ERR_PCT, SER_FRAME_ERR_PCT, SER_BREAK_PCT, SER_GLITCH_PCT|
|baud_deviation|uart_ser_agent_cfg|Dentro y fuera de tolerancia (en %)|80 % dentro, 20 % fuera|SER_BAUD_DEV_MAX, SER_BAUD_OUT_PCT|
|modem_delay, modem_signal|modem_agent_cfg|Ciclos entre cambios; CTS, DSR, RI, DCD|Retardo 98 % corto, 2 % cola; señal uniforme|MODEM_DELAY_MAX, MODEM_CHANGE_PCT|
|polling_interval|uart_env_cfg|0 a 10000 ciclos|98 % en 0 a 100, 2 % cola|SW_POLL_MAX, SW_POLL_TAIL_PCT|
|lsr_check_frequency|uart_env_cfg|0 a N consultas|Uniforme 0 a 4|SW_LSR_CHECK_MAX|
|isr_latency|uart_env_cfg|0 a 100 tiempos de carácter|98 % en 0 a 8, 2 % cola|SW_SERVICE_DELAY_MAX, SW_SERVICE_TAIL_PCT|
|rx_drain_count|uart_env_cfg|1 a 16 bytes por atención|Uniforme|SW_DRAIN_MAX|
|service_ignore_pct|uart_env_cfg|0 a 100|5|SW_IGNORE_PCT|
|reconfig_count, reconfig_target, reg_addr|uart_env_cfg|Conteo; cualquier registro; todas las direcciones con DLAB = 0 y 1|Conteo 0 a 4; destino y dirección uniformes|REG_ACCESS_COUNT, REG_DLAB_PCT|
|wb_sel|wb_agent_cfg|Un solo byte activo (legal)|Uniforme entre los 4 bytes|WB_SEL_WEIGHTS|
|reset aleatorio (momento)|uart_env_cfg|Cualquier ciclo del tráfico|Apagado|RST_EN, RST_PCT|

## 6.2 Argumento de completitud

|Bin o grupo de bins|Por qué su probabilidad es mayor que cero con los valores por defecto|Plusarg que lo acelera|
|---|---|---|
|cg_line_cfg: wls × parity × stop|Todos los pesos son mayores que cero y las tres variables son independientes, así que cada combinación es un producto de probabilidades positivas|LCR_WLS_WEIGHTS, LCR_PARITY_WEIGHTS, LCR_STOP_WEIGHTS|
|cg_div: DL = 0|Tiene 1 % por defecto|DL_ZERO_PCT|
|cg_div: DL de 17 a 65535 (cola)|La cola tiene 2 % y el máximo por defecto es el absoluto|DL_TAIL_PCT, DL_MAX|
|cg_traffic: llenado y desborde de la FIFO de TX|Un payload de 17 a 32 está en la zona rápida y wb_delay corto permite escribir más rápido de lo que el UART serializa|TX_PAYLOAD_MAX, WB_DELAY_MAX|
|cg_err: pe, fe, bi|Cada porcentaje de error es mayor que 0 por defecto|SER_PARITY_ERR_PCT, SER_FRAME_ERR_PCT, SER_BREAK_PCT|
|cg_err: oe × tl|La FIFO de RX se llena si isr_latency supera el tiempo de 16 caracteres; el rango por defecto lo permite gracias a la cola, y los 4 niveles de disparo tienen peso mayor que 0|SW_SERVICE_DELAY_MAX, FCR_TL_WEIGHTS|
|cg_int: iir_id[TIMEOUT]|Con un nivel de disparo mayor que el número de caracteres recibidos y un servicio lento, el tiempo de 4 caracteres se cumple|SW_SERVICE_DELAY_MAX|
|cg_int: iir_id × ier|Los 16 valores de IER son alcanzables y las cuatro fuentes se generan por tráfico, errores, módem y THRE|IER_WEIGHTS|
|cg_modem: delta × signal|modem_signal es uniforme y los cambios ocurren con retardos cortos y largos|MODEM_DELAY_MAX, MODEM_CHANGE_PCT|
|cg_modem|loopback_en tiene 20 % y los 4 bits de MCR son independientes|MCR_LOOPBACK_PCT|
|cg_reg_rst: addr × dlab|La reconfiguración elige cualquier dirección con DLAB = 0 y 1|REG_ACCESS_COUNT, REG_DLAB_PCT|
|cg_reg_rst: reset a mitad de tráfico|**Excepción:** apagado por defecto (E10). Justificación: un reset a mitad de tráfico obliga a vaciar el scoreboard y alarga las corridas. El reset inicial siempre ocurre|RST_EN, RST_PCT|

## 6.2.5 Caso general

|Dimensión|Qué se aleatoriza por defecto|Cola de baja probabilidad|Plusarg que la amplía|
|---|---|---|---|
|Línea|wls, paridad y parada uniformes; DL en 1 a 16|DL = 0 y DL de 17 a 65535|DL_ZERO_PCT, DL_TAIL_PCT|
|FIFO e interrupciones|Niveles de disparo uniformes, IER completo, limpieza de FIFOs|(ninguna)|FCR_TL_WEIGHTS, IER_WEIGHTS|
|Modo|Normal y *loopback* (20 %), MCR y *break*|(ninguna)|MCR_LOOPBACK_PCT|
|Tráfico TX|Ráfagas de 1 a 32|Ráfagas de 33 a 256|TX_PAYLOAD_TAIL_PCT|
|Tráfico RX y errores|Errores con porcentaje mayor que 0, baudios dentro y fuera de tolerancia|Tramas largas, separaciones largas|SER_\*_PCT, SER_PAYLOAD_TAIL_PCT|
|Módem|Cualquiera de las 4 señales, retardos cortos|Retardos largos|MODEM_DELAY_MAX|
|Servicio de software|Polling, interrupciones o mixto|Latencias largas|SW_SERVICE_TAIL_PCT|
|Accesos a registros|Todas las direcciones, DLAB = 1|ninguna|REG_ACCESS_COUNT|
|Reset aleatorio|Solo el reset inicial|Reset a mitad de tráfico|RST_EN, RST_PCT|

### Diagrama de caso general y aleatorización de variables

*(Imagen: flujo de `uart_base_test`. Se describe en texto.)*

```
uart_base_test: randomize() con knobs de plusargs; publica cfg por config_db
 |
 +- Fase 1, configuración (secuencial, vía agente WB)
 |    1. reset, hw_reset_seq
 |    2. DLL, DLM: baudrate
 |    3. LCR: char_length, stop_bit
 |    4. FCR: fifo_trigger
 |    5. IER, MCR: ier_bits
 |
 +- Fase 2, tráfico en paralelo (hilos de secuencia -> agente)
 |    Hilo TX        tx_data_byte, wb_delay, tx_payload_size      -> agente WB
 |    Hilo servicio  notification_mode, isr_latency               -> agente WB
 |    Hilo reconfig  reconfig_count, reg_addr, reconfig_target    -> agente WB
 |    Hilo RX        rx_data_byte, serial_delay, *_err_pct        -> agente serie (inyecta errores)
 |    Hilo módem     modem_signal, modem_delay                    -> agente módem (cambia entradas)
 |    (el agente WB usa un solo bus y arbitra los cuatro hilos que lo comparten)
 |
 +- Fase 3, cierre
      hilos terminan (conteos), FIFO TX vacía, línea en reposo, int_o atendida, drain time

Agentes -> uart_top (DUT, caja negra):
  WB     -> Wishbone: adr, dat, we, stb, ack, dat_o
  serie  -> srx_pad_i, stx_pad_o
  módem  -> cts, dsr, ri, dcd
  DUT    -> int_o (salida de interrupción)
Siempre activos: monitores, scoreboard, aserciones y cobertura observan interfaces e int_o.
```

## 6.3 Secuencia virtual principal

```
uart_main_vseq::body():
// Configuración (secuencial)
aplicar reset inicial
correr uvm_reg_hw_reset_seq // activa por defecto
randomize(cfg) // usa los knobs
escribir LCR con DLAB=1
escribir DLM, luego DLL // MSB primero: el contador arranca con DLL
escribir LCR con DLAB=0
escribir FCR, IER y MCR
// Tráfico (hilos concurrentes)
fork
tx_thread(tx_count) // ráfagas a THR
rx_thread(rx_count) // tramas con errores por srx_pad_i
modem_thread(modem_count) // cambios de CTS, DSR, RI, DCD
service_thread() // polling, interrupciones o ambos
reconfig_thread(reconfig_count) // accesos a registros, DLAB = 1 incluido
reset_thread() // solo si RST_EN = 1
join
// Cierre
esperar FIFO de TX vacía, línea en reposo e int_o atendida
drain time justificado
```

# 7. Tabla de plusargs

|Plusarg|Tipo y rango|Valor por defecto|Componentes que lo usan|Objeto de configuración|Efecto|
|---|---|---|---|---|---|
|+UART_CFG_TXN_MIN|Entero ≥ 1|20|Secuencia virtual principal|uart_env_cfg|Mínimo de transacciones por corrida|
|+UART_CFG_TXN_MAX|Entero ≥ TXN_MIN|200|Secuencia virtual principal|uart_env_cfg|Máximo de transacciones por corrida|
|+UART_LCR_WLS_WEIGHTS|4 pesos (5, 6, 7, 8 bits)|1,1,1,1|Secuencia de configuración, scoreboard|uart_ser_agent_cfg|Pesos de la longitud de carácter|
|+UART_LCR_STOP_WEIGHTS|2 pesos (1 y 2 bits de parada)|1,1|Secuencia de configuración, driver serie|uart_ser_agent_cfg|Pesos de los bits de parada|
|+UART_LCR_PARITY_WEIGHTS|5 pesos (sin paridad, impar, par, stick 1, stick 0)|1,1,1,1,1|Secuencia de configuración, driver serie, scoreboard|uart_ser_agent_cfg|Pesos del tipo de paridad|
|+UART_DL_ZERO_PCT|Entero 0 a 100|1|Secuencia de configuración, scoreboard|uart_ser_agent_cfg|% de corridas con DL = 0|
|+UART_DL_MAX_FAST|Entero 1 a 65535|16|Secuencia de configuración|uart_ser_agent_cfg|Tope de la zona rápida de DL|
|+UART_DL_MAX|Entero 1 a 65535|65535|Secuencia de configuración|uart_ser_agent_cfg|Tope absoluto de DL|
|+UART_DL_TAIL_PCT|Entero 0 a 100|2|Secuencia de configuración|uart_ser_agent_cfg|% de corridas con DL en la cola|
|+UART_FCR_TL_WEIGHTS|4 pesos (1, 4, 8, 14 bytes)|1,1,1,1|Secuencia de configuración, modelo de interrupciones|uart_ser_agent_cfg|Pesos del nivel de disparo|
|+UART_FCR_CLEAR_PCT|Entero 0 a 100|10|Secuencia de reconfiguración|uart_ser_agent_cfg|% de escrituras a FCR que limpian las FIFOs|
|+UART_IER_WEIGHTS|4 enteros 0 a 100 (bits 0 a 3)|50,50,50,50|Secuencia de configuración, modelo de interrupciones|modem_agent_cfg|Probabilidad de que cada bit de IER sea 1|
|+UART_MCR_LOOPBACK_PCT|Entero 0 a 100|20|Secuencia de configuración, scoreboard|modem_agent_cfg|% de corridas en loopback|
|+UART_MCR_WEIGHTS|4 enteros 0 a 100 (DTR, RTS, OUT1, OUT2)|50,50,50,50|Secuencia de configuración, scoreboard|modem_agent_cfg|Probabilidad de que cada bit del MCR sea 1|
|+UART_SW_MODE_WEIGHTS|3 pesos (POLLING, INTERRUPT, MIXED)|1,1,1|Hilo de servicio|uart_env_cfg|Pesos del estilo de servicio del software|
|+UART_TX_PAYLOAD_MAX|Entero ≥ 1|32|Secuencia TX|uart_ser_agent_cfg|Tope de la zona rápida de la ráfaga TX|
|+UART_TX_PAYLOAD_TAIL_PCT|Entero 0 a 100|2|Secuencia TX|uart_ser_agent_cfg|% de ráfagas TX largas (hasta 256)|
|+UART_TX_BREAK_PCT|Entero 0 a 100|3|Secuencia de configuración, scoreboard|uart_ser_agent_cfg|% de corridas que activan break en LCR[6]|
|+UART_WB_DELAY_MAX|Entero ≥ 0 (ciclos)|20|Driver Wishbone|wb_agent_cfg|Tope de la zona rápida del retardo entre transacciones|
|+UART_WB_DELAY_TAIL_PCT|Entero 0 a 100|2|Driver Wishbone|wb_agent_cfg|% de retardos largos (hasta 1000)|
|+UART_WB_SEL_WEIGHTS|4 pesos (un byte activo, bytes 0 a 3)|1,1,1,1|Driver Wishbone, scoreboard|wb_agent_cfg|Pesos de wb_sel_i legal|
|+UART_SER_PAYLOAD_MAX|Entero ≥ 1|32|Secuencia RX|uart_ser_agent_cfg|Tope de la zona rápida de tramas RX|
|+UART_SER_PAYLOAD_TAIL_PCT|Entero 0 a 100|2|Secuencia RX|uart_ser_agent_cfg|% de ráfagas RX largas (hasta 256)|
|+UART_SER_DELAY_MAX|Entero ≥ 0 (tiempos de bit)|20|Driver serie|uart_ser_agent_cfg|Tope de la zona rápida de separación entre tramas|
|+UART_SER_DELAY_TAIL_PCT|Entero 0 a 100|2|Driver serie|uart_ser_agent_cfg|% de separaciones largas (hasta 1000)|
|+UART_SER_PARITY_ERR_PCT|Entero 0 a 100|5|Driver serie, scoreboard|uart_ser_agent_cfg|% de caracteres RX con paridad corrupta|
|+UART_SER_FRAME_ERR_PCT|Entero 0 a 100|5|Driver serie, scoreboard|uart_ser_agent_cfg|% de caracteres RX con error de trama|
|+UART_SER_BREAK_PCT|Entero 0 a 100|2|Driver serie, scoreboard|uart_ser_agent_cfg|% de tramas RX que son break|
|+UART_SER_GLITCH_PCT|Entero 0 a 100|3|Driver serie, scoreboard|uart_ser_agent_cfg|% de tramas RX con glitch en la línea|
|+UART_SER_BAUD_DEV_MAX|Entero 0 a 100 (%)|10|Driver serie|uart_ser_agent_cfg|Desviación máxima de baudrate que genera el driver|
|+UART_SER_BAUD_OUT_PCT|Entero 0 a 100|20|Driver serie, scoreboard|uart_ser_agent_cfg|% de tramas con desviación fuera de tolerancia|
|+UART_MODEM_DELAY_MAX|Entero ≥ 0 (ciclos)|50|Driver de módem|modem_agent_cfg|Tope de la zona rápida entre cambios de módem|
|+UART_MODEM_CHANGE_PCT|Entero 0 a 100|50|Driver de módem|modem_agent_cfg|Probabilidad de cambio de cada entrada en cada paso|
|+UART_SW_POLL_MAX|Entero ≥ 0 (ciclos)|100|Hilo de servicio|uart_env_cfg|Tope de la zona rápida del intervalo de polling|
|+UART_SW_POLL_TAIL_PCT|Entero 0 a 100|2|Hilo de servicio|uart_env_cfg|% de intervalos largos (hasta 10000)|
|+UART_SW_LSR_CHECK_MAX|Entero ≥ 0|4|Hilo de servicio|uart_env_cfg|Máximo de lecturas de LSR antes de leer IIR|
|+UART_SW_SERVICE_DELAY_MAX|Entero ≥ 0 (tiempos de carácter)|8|Hilo de servicio|uart_env_cfg|Tope de la zona rápida de la latencia de atención|
|+UART_SW_SERVICE_TAIL_PCT|Entero 0 a 100|2|Hilo de servicio|uart_env_cfg|% de latencias largas (hasta 100)|
|+UART_SW_DRAIN_MAX|Entero 1 a 16|16|Hilo de servicio|uart_env_cfg|Máximo de bytes leídos de RBR por atención|
|+UART_SW_IGNORE_PCT|Entero 0 a 100|5|Hilo de servicio|uart_env_cfg|% de interrupciones que el software ignora|
|+UART_REG_ACCESS_COUNT|Entero ≥ 0|4|Hilo de reconfiguración|uart_env_cfg|Máximo de accesos o reconfiguraciones por corrida|
|+UART_REG_DLAB_PCT|Entero 0 a 100|20|Hilo de reconfiguración|uart_env_cfg|% de accesos hechos con DLAB = 1|
|+UART_REG_BITBASH_EN|0 o 1|0|Secuencia de configuración, RAL|uart_env_cfg|Corre uvm_reg_bit_bash_seq|
|+UART_REG_ACCESS_EN|0 o 1|0|Secuencia de configuración, RAL|uart_env_cfg|Corre uvm_reg_access_seq|
|+UART_RST_EN|0 o 1|0|Hilo de reset, scoreboard|uart_env_cfg|Habilita el reset aleatorio a mitad de tráfico|
|+UART_RST_PCT|Entero 0 a 100|10|Hilo de reset|uart_env_cfg|Probabilidad de reset aleatorio por corrida (solo con RST_EN=1)|

# 8. Casos de esquina planificados

|ID|Escenario|Archivo. args|Plusargs|Bins objetivo|Semillas|
|---|---|---|---|---|---|
|CE-01|Solo 5 bits con 2 bits de parada (1.5)|lcr_5bit_stop15.args|+UART_LCR_WLS_WEIGHTS=1,0,0,0 +UART_LCR_STOP_WEIGHTS=0,1|cg_line_cfg.cp_wls[5] × cp_stop[2]|10|
|CE-02|DL = 0 siempre: no hay TX ni RX|dl_zero.args|+UART_DL_ZERO_PCT=100|cg_div.cp_dl[0]|10|
|CE-03|Overrun de RX con nivel de disparo 14|rx_overrun_tl14.args|+UART_FCR_TL_WEIGHTS=0,0,0,1 +UART_SW_SERVICE_TAIL_PCT=100 +UART_SW_SERVICE_DELAY_MAX=100|cg_err.cp_oe × cp_tl[14]|20|
|CE-04|Timeout: pocos caracteres y servicio lento|int_timeout_tl14.args|+UART_FCR_TL_WEIGHTS=0,0,0,1 +UART_SER_PAYLOAD_MAX=3 +UART_SER_PAYLOAD_TAIL_PCT=0 +UART_SW_SERVICE_TAIL_PCT=100|cg_int.cp_iir_id[TIMEOUT]|20|
|CE-05|Cambios de módem muy frecuentes|modem_change_100.args|+UART_MODEM_CHANGE_PCT=100|cg_modem.cp_delta × cp_signal|10|
|CE-06|Loopback siempre activo|loopback_on.args|+UART_MCR_LOOPBACK_PCT=100|cg_modem.cp_lb_en × cp_mcr_out|10|
|CE-07|Reset a mitad de tráfico|rst_mid_traffic.args|+UART_RST_EN=1 +UART_RST_PCT=100|cg_reg_rst.cp_reset_state (reposo, TX, RX)|20|
|CE-08|Retardos largos entre transacciones Wishbone|wb_delay_long.args|+UART_WB_DELAY_TAIL_PCT=100|cg_traffic.cp_addr; A-WB-01 a A-WB-03 (cover)|10|
|CE-09|Paridad stick 1 fija|parity_stick1.args|+UART_LCR_PARITY_WEIGHTS=0,0,0,1,0|cg_line_cfg.cp_parity[STICK1] × cp_wls|10|
|CE-10|Break de transmisión frecuente|tx_break_100.args|+UART_TX_BREAK_PCT=100|cg_line_cfg.cp_tx_break|10|
|CE-11|DL = 1 (el más rápido)|dl_fastest.args|+UART_DL_MAX_FAST=1 +UART_DL_ZERO_PCT=0|cg_div.cp_dl (zona rápida)|10|
|CE-12|Explorar la cola de DL|dl_tail.args|+UART_DL_TAIL_PCT=100|cg_div.cp_dl (cola)|10|

# 9. Arquitectura del ambiente

## 9.1 Diagrama

*(Imagen: arquitectura del ambiente. Se describe en texto.)*

```
uart_base_test: parse_plusargs -> cfgs -> config_db
 |
 v
uart_env
  virtual_sequencer (corre uart_main_vseq) -> seqr de wb, ser y modem
  reg_block: RAL + predictor   -> scoreboard
  scoreboard + modelo de ref.
  coverage (monitores, RAL, scoreboard)
  wb_agent      emula CPU       seqr -> driver | monitor
  ser_agent     emula otro UART seqr -> driver | monitor
  modem_agent   emula módem     seqr -> driver | monitor
  int_monitor   pasivo, solo observa
  Los monitores alimentan RAL/predictor, scoreboard y coverage.
 |
 v
tb_top
  wb_if (bus Wishbone), uart_if (línea serie), modem_if (señales de módem), int_if (solo observa)
  uart_top (DUT, caja negra)
    entradas WB: wb_adr_i, wb_dat_i, wb_sel_i, wb_we_i, wb_stb_i, wb_cyc_i; salidas: wb_dat_o, wb_ack_o
    serie: entrada srx_pad_i; salida stx_pad_o
    módem: entradas cts_pad_i, dsr_pad_i, ri_pad_i, dcd_pad_i; salidas rts_pad_o, dtr_pad_o
    salida int_o (opcional: baud_o)
  reloj y reset (wb_clk_i, wb_rst_i)
  módulo SVA (bind: WB, serie, loopback)
Leyenda: estímulo (seqr, virtual_sequencer), driver, monitores y análisis.
```

## 9.2 Componentes

|Componente|Clase UVM base|Responsabilidad|Puertos TLM|
|---|---|---|---|
|uart_base_test|uvm_test|Lee los plusargs (parse_plusargs()), crea los cfg, los publica en config_db y lanza uart_main_vseq|(ninguno)|
|uart_env|uvm_env|Crea por factory y conecta agentes, RAL, scoreboard y cobertura|(ninguno)|
|virtual_sequencer|uvm_sequencer|Tiene los handles de los tres secuenciadores (WB, serie, módem) y corre la secuencia principal|(ninguno)|
|uart_main_vseq|uvm_sequence|Flujo de 6.3: configura, lanza los hilos concurrentes y cierra|(ninguno)|
|wb_agent: seqr|uvm_sequencer|Arbitra TX, servicio y reconfiguración sobre el único bus Wishbone|(ninguno)|
|wb_agent: driver|uvm_driver|Maestro Wishbone: retardos aleatorios, wb_sel_i|(ninguno)|
|wb_agent: monitor|uvm_monitor|Observa wb_if y publica cada transacción|wb_ap|
|ser_agent: seqr|uvm_sequencer|Secuencia el tráfico RX hacia el DUT|(ninguno)|
|ser_agent: driver|uvm_driver|Emula otro UART: envía por srx_pad_i con errores, glitches y desviación de baudrate|(ninguno)|
|ser_agent: monitor|uvm_monitor|Reconstruye caracteres de stx_pad_o y srx_pad_i|tx_ap, rx_ap|
|modem_agent: seqr|uvm_sequencer|Secuencia los cambios de módem|(ninguno)|
|modem_agent: driver|uvm_driver|Maneja CTS, DSR, RI y DCD|(ninguno)|
|modem_agent: monitor|uvm_monitor|Observa las cuatro entradas y RTS y DTR|modem_ap|
|int_monitor (pasivo)|uvm_monitor|Observa int_o en int_if y publica el evento “int_o sube” para el hilo de servicio|int_ap|
|reg_block (RAL)|uvm_reg_block|Registros, y un unico mapa de DLAB, puerta trasera a uart_top.regs.\*|(ninguno)|
|uart_reg_adapter|uvm_reg_adapter|reg2bus y bus2reg para-Wishbone|(ninguno)|
|uart_predictor|uvm_reg_predictor|Actualiza el espejo del RAL con lo observado en el bus|bus_in (desde wb_ap)|
|scoreboard + modelo de ref.|uvm_scoreboard y uvm_component|Predice y compara TX, RX, LSR, MSR, IIR e int_o|un analysis_imp por fuente (wb_ap, tx_ap, rx_ap, modem_ap, int_ap)|
|coverage|uvm_subscriber|Covergroups de la sección 13, muestreados desde monitores, RAL y scoreboard|analysis_imp por fuente|
|tb_top|módulo SV|Instancia el DUT, las interfaces, el reloj y el reset, publica las interfaces virtuales y arranca la prueba|(no es UVM)|
|wb_if, uart_if, modem_if, int_if|interface SV|Conectan los agentes con el DUT; int_if solo observa|(no es UVM)|
|módulo SVA|módulo SV con bind|Aserciones de Wishbone, serie y loopback, cada una con su cover|(no es UVM)|

## 9.3 Flujo de configuración

|Objeto de configuración|Ruta en uvm_config_db|Lo publica|Lo obtienen|
|---|---|---|---|
|uart_env_cfg|uvm_test_top.env\*|uart_base_test|uart_env, virtual_sequencer, uart_main_vseq (hilos de servicio, reconfiguración y reset)|
|wb_agent_cfg|uvm_test_top.env.wb_agt\*|uart_base_test|Driver, monitor, secuenciador y secuencias Wishbone; adaptador del RAL (ancho de bus)|
|uart_ser_agent_cfg|uvm_test_top.env.ser_agt\*|uart_base_test|Driver, monitor, secuenciador y secuencias serie; secuencia de configuración|
|modem_agent_cfg|uvm_test_top.env.modem_agt\*|uart_base_test|Driver, monitor, secuenciador y secuencias de módem|
|uart_scb_cfg|uvm_test_top.env.scb\*|uart_base_test|Scoreboard y modelo de referencia|
|uart_cov_cfg|uvm_test_top.env.cov\*|uart_base_test|coverage|
|uart_reg_block (handle del RAL)|uvm_test_top.env\*|uart_env (en build_phase)|Driver y monitor serie (para leer LCR y DL del espejo), predictor, scoreboard y secuencias de registros|
|Interfaz virtual wb_if|uvm_test_top.env.wb_agt\*|tb_top|Driver y monitor Wishbone|
|Interfaz virtual uart_if|uvm_test_top.env.ser_agt\*|tb_top|Driver y monitor serie|
|Interfaz virtual modem_if|uvm_test_top.env.modem_agt\*|tb_top|Driver y monitor de módem|
|Interfaz virtual int_if|uvm_test_top.env.int_mon\*|tb_top|int_monitor|

# 10. Modelo de referencia y scoreboard

|Qué se predice|Fuente de la predicción|Momento de la comparación|Tolerancia|
|---|---|---|---|
|Datos TX|Escrituras a THR vistas por el monitor Wishbone (wb_ap), recortadas a la longitud de carácter vigente|Al reconstruir el carácter en stx_pad_o (tx_ap)|Ninguna|
|Datos RX|Caracteres que el driver serie envía por srx_pad_i (rx_ap), con el formato vigente del espejo del RAL|Cuando el software lee RBR por Wishbone (wb_ap)|Ninguna|
|LSR|Modelo de las FIFOs y de los errores (paridad, trama, break, overrun) con lo observado en rx_ap, tx_ap y wb_ap|En cada lectura de LSR por Wishbone; después de leer se limpian los bits de error en el modelo|Ninguna en los bits de error y DR. En THRE y TEMT, ventana de unos ciclos de reloj (por definir)|
|IIR|Modelo de interrupciones: IER (espejo del RAL), LSR del modelo, nivel de la FIFO RX contra el nivel de disparo, timeout, deltas de MSR y THRE, con la prioridad de la especificación|En cada lectura de IIR por Wishbone|Ninguna, salvo el timeout: ventana alrededor de los 4 tiempos de carácter|
|MSR|Entradas de módem (modem_ap) y MCR del espejo; en loopback, las salidas del MCR|En cada lectura de MSR por Wishbone; los deltas se limpian en el modelo al leer|Ninguna|
|int_o|Modelo de interrupciones: IER y causas pendientes|En cada cambio de int_o (int_ap) y en cada lectura de IIR|Pocos ciclos de reloj por sincronización (por definir). Ventana mayor en el timeout|
|RTS y DTR|MCR del espejo, con la polaridad definida en la sección 3|En cada cambio observado en modem_ap|Ninguna|
|Estado tras reset|Valores de reset de la especificación; el modelo vacía sus FIFOs y se reinicia|Al detectar el reset|Ninguna|
|Transmisión y recepción con DL = 0|El modelo no espera caracteres|En todo momento con DL = 0|Ninguna|

# 11. Aserciones

|ID|Interfaz|Propiedad (en palabras)|Tipo (assert, assume, cover)|Ítem del plan|
|---|---|---|---|---|
|A-WB-01|Wishbone|adr, dat_i, we y sel se mantienen estables mientras cyc y stb están activos y no hay ack|assert y cover|V-WB-01|
|A-WB-02|Wishbone|Después de cyc && stb, ack llega en un número acotado de ciclos|assert y cover|V-WB-01|
|A-WB-03|Wishbone|Ninguna señal del bus (ack, dat_o) tiene X o Z tras el reset|assert y cover|V-WB-01|
|A-SER-01|Serie|stx_pad_o está en 1 en reposo (sin transmisión ni break)|assert y cover|V-TX-01, V-LCR-03|
|A-SER-02|Serie|Cada bit de stx_pad_o dura 16 × DL ciclos de reloj (con DL ≠ 0)|assert y cover|V-DIV-01|
|A-LB-01|Loopback|Con MCR[4] = 1, stx_pad_o se mantiene en 1|assert y cover|V-LB-01|

# 12. RAL

## 12.1 Registros y campos

|Registro|Dirección|DLAB|Campo|Bits|Acceso|Reset|Ruta de puerta trasera|
|---|---|---|---|---|---|---|---|
|RBR|0|0 lectura|data|7:0|RO|FIFO vacía|(sin ruta: es la FIFO)|
|THR|0|0 escritura|data|7:0|WO|FIFO vacía|(sin ruta: es la FIFO)|
|DLL|0|1|dl_lsb|7:0|RW|8'h00|uart_top.regs.dl[7:0]|
|DLM|1|1|dl_msb|7:0|RW|8'h00|uart_top.regs.dl[15:8]|
|IER|1|0|erbfi, etbei, elsi, edssi|3:0|RW|4'h0|uart_top.regs.ier|
|IER|1|0|reservado|7:4|RO|4'h0|(sin ruta)|
|IIR|2|0 y 1|int_pending|0|RO|1|uart_top.regs.iir[0]|
|IIR|2|0 y 1|int_id|3:1|RO|3'b000|uart_top.regs.iir[3:1]|
|IIR|2|0 y 1|reservado y fifo_en|7:4|RO|4'hC|(sin ruta)|
|FCR|2|0 y 1|rx_fifo_rst, tx_fifo_rst|2:1|WO|0|(sin ruta: pulso)|
|FCR|2|0 y 1|rx_trigger|7:6|WO|2'b11|uart_top.regs.fcr|
|FCR|2|0 y 1|--|0, 5:3|WO|0|(sin ruta)|
|LCR|3|0 y 1|wls|1:0|RW|2'b11|uart_top.regs.lcr[1:0]|
|LCR|3|0 y 1|stb, pen, eps, sp, bc|6:2|RW|0|uart_top.regs.lcr[6:2]|
|LCR|3|0 y 1|dlab|7|RW|0|uart_top.regs.lcr[7]|
|MCR|4|0 y 1|dtr, rts, out1, out2, loop|4:0|WO|0|uart_top.regs.mcr|
|MCR|4|0 y 1|--|7:5|WO|0|--|
|LSR|5|0 y 1|dr|0|RO|0|uart_top.regs.lsr[0]|
|LSR|5|0 y 1|oe, pe, fe, bi|4:1|RC|0|uart_top.regs.lsr[4:1]|
|LSR|5|0 y 1|thre, temt|6:5|RO|2'b11|uart_top.regs.lsr[6:5]|
|LSR|5|0 y 1|error_en_fifo|7|RC|0|uart_top.regs.lsr[7]|
|MSR|6|0 y 1|dcts, ddsr, teri, ddcd|3:0|RC|0|uart_top.regs.msr[3:0]|
|MSR|6|0 y 1|cts, dsr, ri, dcd|7:4|RO|--|uart_top.regs.msr[7:4]|
|Debug 1|8|0 y 1|lsr, ier, iir, lcr, msr copias|31:0|RO|refleja los registros|uart_top.regs.\* de cada uno|
|Debug 2|12|0 y 1|estados de TX y RX, contadores de FIFO, mcr, fcr|23:0|RO|refleja el estado|uart_top.regs.\* de cada uno|
|Debug 2|12|0 y 1|reservado|31:24|RO|0|--|
|SCR|7|0 y 1|scratch|7:0|RW|8'h00|uart_top.regs.scratch|

## 12.2 Decisiones de modelado

|Tema|Decisión|Justificación|
|---|---|---|
|Registros con dirección compartida (DLAB)|Un solo mapa de direcciones con DLL y DLM como registros aparte (dirección 0 y 1, DLAB = 1). IIR y FCR son dos registros distintos en la dirección 2. La secuencia de registros activa DLAB antes de acceder a DLL y DLM y lo restaura después.|Es la solución más simple, y el RAL se mantiene en un solo mapa. Un segundo mapa para DLAB = 1 es la alternativa si el acceso se complica.|
|Predictor y adaptador|uvm_reg_predictor explícito conectado a wb_ap, con auto-predicción apagada. El adaptador hace reg2bus y bus2reg para Wishbone, con wb_sel_i según la dirección.|El predictor ve todos los accesos al bus, no solo los del RAL, así el espejo no queda desactualizado.|
|Efectos laterales|RBR y THR se tratan como puertos sin espejo de dato (la FIFO la modela el scoreboard). Los bits que se limpian al leer (LSR, MSR) usan acceso RC. IIR se compara contra el modelo de interrupciones.|El RAL no conoce FIFOs ni eventos externos, así que estos registros se verifican con el scoreboard y no con mirror() directo.|
|Secuencias integradas y exclusiones|uvm_reg_hw_reset_seq siempre, por puerta delantera y trasera. bit_bash y access solo con REG_BITBASH_EN y REG_ACCESS_EN. Excluir con NO_REG_TESTS: RBR, THR, IIR, LSR, MSR, DLL, DLM, Debug 1 y Debug 2.|Son registros de solo lectura o solo escritura, con efectos laterales o dependientes del estado interno, donde bit_bash daría fallas falsas.|

# 13. Modelo de cobertura funcional

|Covergroup|Dónde se muestrea|Coverpoints|Cruces|Bins ilegales o ignorados (justificación)|
|---|---|---|---|---|
|cg_line_cfg|Monitor Wishbone al escribir LCR (valor tomado del espejo del RAL)|cp_wls (5, 6, 7, 8), cp_stop (1, 2), cp_parity (ninguna, impar, par, *stick* 1, *stick* 0), cp_tx_break, cp_dir (TX, RX)|wls × stop × parity; wls × dir|*Stick* sin paridad habilitada: ignorado, no tiene efecto. Con 5 bits, el bin “2 bits de parada” se cuenta como 1.5|
|cg_div|Monitor Wishbone al escribir DLL y DLM|cp_dl (0, zona rápida 1 a 16, cola 17 a 65535)|Ninguno|Ninguno: DL = 0 es legal y está en la matriz (V-DIV-02)|
|cg_traffic|Monitores Wishbone y serie; scoreboard para el nivel de la FIFO|cp_burst_len (TX), cp_rx_len, cp_dr, cp_thre, cp_temt, cp_fifo_level (vacía, parcial, llena, desborde), cp_baud_dev (dentro, fuera), cp_wb_sel, cp_addr, cp_tx_write_full|burst_len × fifo_level; wb_sel × addr|Desborde de TX y wb_sel con varios bits activos: pendientes de decidir en la sección 3|
|cg_fifo|Scoreboard (modelo de FIFOs)|cp_tl (1, 4, 8, 14), cp_rx_level, cp_clear_rx, cp_clear_tx|tl × rx_level|--|
|cg_err|Scoreboard, al comparar LSR|cp_pe, cp_fe, cp_bi, cp_oe, cp_tl (1, 4, 8, 14)|oe × tl|--|
|cg_int|Monitor de interrupción y scoreboard, al leer IIR|cp_iir_id (línea, datos, *timeout*, THRE, módem, ninguna), cp_ier (16 valores), cp_int_o, cp_mode (*polling*, interrupciones, mixto)|iir_id × ier; int_o × ier|Combinaciones de iir_id cuya fuente está deshabilitada en IER: ignoradas, el hardware no las puede generar|
|cg_modem|Monitor de módem y scoreboard, al leer MSR|cp_signal (CTS, DSR, RI, DCD), cp_delta, cp_msr_state, cp_mcr_out, cp_lb_en|delta × signal; lb_en × mcr_out|--|
|cg_reg_rst|Monitor Wishbone y RAL (predictor)|cp_addr (0 a 8, 12 y 7 si hay *scratch*), cp_dlab, cp_side_effect, cp_reg_access, cp_debug_read, cp_reset_state (reposo, TX, RX)|addr × dlab|Escritura a registros de solo lectura (LSR, MSR, Debug): ignorada, no tiene efecto. Los bins de cp_reset_state solo se alcanzan con RST_EN=1 y van al informe de cierre|

# 14. Cobertura de código

|Métrica|Jerarquía incluida|Meta|Exclusiones previstas y justificación|
|---|---|---|---|
|Línea|uart_top y sus instancias (uart_wb, uart_regs, uart_transmitter, uart_receiver, uart_tfifo, uart_rfifo, raminfr, uart_sync_flops, uart_debug_if)|≥ 95 %|Código del bus de 8 bits (DATA_BUS_WIDTH_8): no se compila en la variante de 32 bits. Lógica de baud_o: UART_HAS_BAUDRATE_OUTPUT no está definido|
|Condición|Igual|≥ 95 %|Términos de condiciones ligados a las opciones de compilación no activas (8 bits, baud_o). Términos que dependen de bits constantes|
|Rama|Igual|≥ 95 %|Ramas default imposibles de case completos. Ramas del bus de 8 bits|
|FSM|Igual (FSM del transmisor, del receptor y de uart_regs)|≥ 95 %|Estados o transiciones inalcanzables según el RTL. Se verifican en el reporte antes de excluir|
|Toggle|Igual|≥ 95 %|Bits constantes: IER[7:4] = 0, IIR[5:4] = 0 e IIR[7:6] = 1, MCR[7:5], FCR ignorados y Debug 2[31:24] = 0. Señales del modo de 8 bits y de baud_o|

# 15. Criterios de cierre

|Criterio|Meta|Cómo se mide|
|---|---|---|
|Cobertura funcional|≥ 95 %|Reporte de urg sobre la regresión fusionada (línea base más los .args)|
|Cada métrica de cobertura de código (línea, condición, rama, FSM, toggle)|≥ 95 %|Reporte de urg con -cm_hier limitado a uart_top y las exclusiones del .el|
|UVM_ERROR y UVM_FATAL en la regresión|0, salvo errores del DUT documentados|Conteo en los logs de todas las corridas|
|Aserciones con cover alcanzado|100 %|Reporte de cobertura de aserciones de urg|
|Línea base|N ≥ 200 semillas con valores por defecto y curva de saturación|Gráfica de cobertura contra número de semillas|
|Huecos restantes|Todos clasificados (alcanzable, falta estímulo, inalcanzable o error del DUT) y justificados|Tabla de huecos del informe de cierre|
|Reproducibilidad|Cualquier corrida se repite con semilla y .args|Traza de knobs con su origen al inicio de cada log (E7)|
|Secuencia de reset de registros|uvm_reg_hw_reset_seq pasa por puerta delantera y trasera|Resultado de la corrida de la línea base|

# 16. Riesgos y mitigación

|Riesgo|Impacto|Mitigación|
|---|---|---|
|Discrepancias entre la especificación y el RTL (*scratch*, polaridades de MSR y MCR, bits de parada) generan fallas falsas en el scoreboard y el RAL|Alto: bloquea la línea base y el cierre|Revisar el RTL en la semana 1 y fijar cada comportamiento en la sección 3. Excluir con NO_REG_TESTS lo que sea dudoso hasta confirmarlo|
|Tiempo de simulación largo con DL grande o ráfagas largas, que impide correr 200 o más semillas|Medio: la curva de saturación y el cierre se retrasan|Acotar rangos por defecto (zona rápida de DL, tamaño de ráfaga) con cola alcanzable, y usar CFG_TXN_MIN y CFG_TXN_MAX para controlar la duración. Correr la regresión en paralelo|
|La regresión es inestable o no reproducible (fallas que dependen de la semilla, .vdb perdidos, corridas que no se pueden repetir)|Alto: no se puede fusionar la cobertura ni demostrar un fallo|Script único (Makefile o Python) que fija semilla, .args y -cm_name \<prueba>_\<semilla>. Guardar el log con la traza de knobs de cada corrida. Correr una regresión corta (por ejemplo 20 semillas) en cada cambio al repositorio, antes de la completa|

# 17. Distribución del trabajo

Cada integrante es responsable principal de algunos componentes, pero los tres deben entender todo el ambiente (entrevista individual, sección 8.2 del enunciado).

|Componente o tarea|Responsable principal|Revisor|Semana|
|---|---|---|---|
|Compilar el RTL en VCS y leer la especificación|Los tres|Los tres|S1|
|Plan de pruebas: secciones 1 a 5 y 3 (interpretación de la especificación)|Randy|Eric|S1-S2|
|Plan de pruebas: secciones 6, 7 y 8 (estímulo, plusargs, casos de esquina)|Diego|Randy|S2|
|Plan de pruebas: secciones 9 a 17|Eric|Diego|S2|
|Hacer el plan de 0|Ronny|Ronny|S2|
|Interfaces, tb_top, reloj y reset|Eric|Diego|S3|
|Agente Wishbone y wb_agent_cfg|Eric|Diego|S3|
|RAL: bloque, adaptador, predictor y uvm_reg_hw_reset_seq|Eric|Diego|S3-S4|
|Agente serie (driver, monitor, errores) y uart_ser_agent_cfg|Diego|Randy|S3|
|Secuencias TX y RX|Diego|Randy|S3-S4|
|Agente de módem, monitor de interrupción y modem_agent_cfg|Randy|Eric|S3|
|Virtual sequencer, uart_main_vseq, hilo de servicio y uart_env_cfg|Randy|Eric|S3-S4|
|parse_plusargs(), check_knobs() y traza de knobs (E7)|Randy|Diego|S3|
|Scoreboard y modelo de referencia (TX, RX, LSR, IIR, MSR, int_o)|Randy|Eric|S4|
|Aserciones SVA de Wishbone|Eric|Diego|S4|
|Aserciones SVA de serie y *loopback*|Diego|Randy|S4|
|Covergroups y uart_cov_cfg|Diego|Eric|S5|
|Script de regresión, fusión con urg y curva de línea base|Eric|Randy|S5|
|Análisis de huecos, archivos .args y archivo .el de exclusiones|Los tres|Los tres|S6|
|Informe de errores del DUT, informe final y demostración|Los tres|Los tres|Final|
