# Proyecto: verificación del UART 16550 con UVM

> **Verificación funcional de circuitos integrados · SystemVerilog y UVM**
> Curso EL5811 · Enunciado del proyecto UVM · 2026
>
> **Documento de referencia fijo (no se modifica).** Transcripción del enunciado oficial, versión del 16 de octubre de 2026.
> El estado vivo del proyecto (cambios, metas, issues, boards de Git) va en un archivo aparte.

Cada grupo de tres estudiantes construirá desde cero un ambiente de verificación UVM para el núcleo UART 16550 de OpenCores, lo llevará al menos a 95 % de cobertura funcional y de código, y justificará técnicamente cualquier hueco que no logre cerrar.

**Fecha de entrega:** Lunes de semana 18 · **Grupos de 3** · Synopsys VCS + UVM 1.2 · **Versión del 16 de octubre de 2026**

---

## 1. Información general

| Aspecto | Detalle |
|---|---|
| Modalidad | Grupos de 3 estudiantes. Cada integrante debe poder explicar y modificar cualquier parte del código entregado (ver la entrevista individual, sección 8.2). |
| Fecha de entrega | **Lunes de semana 18** (entrega final E3) |
| Simulador | Synopsys VCS (con `-ntb_opts uvm-1.2`), cobertura con URG / Verdi |
| Metodología | UVM 1.2, SystemVerilog IEEE 1800-2017 |
| Control de versiones | Repositorio Git privado por grupo; el profesor debe tener acceso de lectura desde la semana 1. Cada integrante hace commits con su propia cuenta. |
| DUT | `uart16550` de OpenCores (RTL en Verilog, interfaz Wishbone, compatible con 16550A) |

No se permite reutilizar ambientes UVM existentes para este núcleo (de GitHub, cursos previos o generadores automáticos). Sí se permite usar la documentación de UVM, VIPs de referencia como **ejemplo de estilo**, y el banco de pruebas Verilog original del proyecto solo como referencia de comportamiento.

El trabajo se reparte entre los tres integrantes, pero la responsabilidad sobre el código es compartida: dividir el ambiente en partes no exime a nadie de entender las partes que escribieron los demás.

---

## 2. Objetivos de aprendizaje

Al terminar el proyecto, cada estudiante será capaz de:

1. Extraer de una especificación las características verificables de un dispositivo y convertirlas en un plan de pruebas con métricas de cierre.
2. Diseñar una **prueba base aleatoria restringida** cuyo espacio de estímulos cubra, en teoría, todas las configuraciones y todo el tráfico que el DUT soporta.
3. Dirigir esa misma prueba hacia casos de esquina modificando restricciones mediante **plusargs** propagados por objetos de configuración en `uvm_config_db`, sin escribir pruebas dirigidas desde cero.
4. Implementar una arquitectura UVM completa: agentes activos y pasivos, secuenciador virtual, secuencias, scoreboard con modelo de referencia, aserciones SVA de interfaz, RAL con predictor, adaptador y acceso por puerta delantera y trasera, y cobertura funcional.
5. Analizar cobertura funcional y de código (línea, condición, rama, FSM y *toggle*), proponer pruebas adicionales para cerrar huecos y justificar exclusiones con criterio técnico.
6. Documentar y reportar errores del RTL encontrados durante la verificación, distinguiendo entre defectos del diseño, ambigüedades de la especificación y errores del propio ambiente.

---

## 3. El dispositivo bajo prueba: UART 16550

El DUT es `uart16550`, un UART compatible con el NS16550A con interfaz Wishbone Rev. B, marcado como *Stable* en OpenCores. Se eligió porque tiene RTL completo (unas 3 600 líneas de Verilog), especificación de registros detallada, dos interfaces de protocolo muy distintas (bus paralelo y serie asíncrona), FIFOs, interrupciones con prioridad, señales de módem, modo *loopback* y registros multiplexados por el bit DLAB, lo cual hace interesante el modelado RAL. Además tiene errores reportados y diferencias entre especificación y RTL que un buen ambiente debe detectar.

### 3.1 Dónde obtener el RTL y la documentación

| Recurso | Enlace | Uso |
|---|---|---|
| Página del proyecto | opencores.org/projects/uart16550 | Descripción, estado, mantenedores |
| Descarga del proyecto completo | opencores.org/download/uart16550 | Requiere cuenta gratuita en OpenCores |
| Repositorio SVN | opencores.org/websvn/listing/uart16550 | Historial de cambios |
| Espejo en GitHub (recomendado) | github.com/freecores/uart16550 | `git clone https://github.com/freecores/uart16550.git` |
| Especificación original (PDF) | `docs/UART_spec.pdf` en el repositorio | **Documento normativo** del proyecto |
| Especificación revisada (Rev. 0.6.1) | uart16550.readthedocs.io | Misma información en HTML, con aclaraciones y la lista de errores conocidos |
| Bugtracker | opencores.org/projects/uart16550/bugtracker | Errores reportados por la comunidad |

Usen únicamente el directorio `rtl/verilog/` (no `rtl/verilog-backup/`). Los archivos del DUT son: `uart_top.v`, `uart_wb.v`, `uart_regs.v`, `uart_transmitter.v`, `uart_receiver.v`, `uart_tfifo.v`, `uart_rfifo.v`, `raminfr.v`, `uart_sync_flops.v`, `uart_debug_if.v`, `uart_defines.v` y `timescale.v`. El directorio `bench/verilog/` contiene un banco de pruebas Verilog antiguo que pueden consultar, pero no reutilizar.

### 3.2 Configuración de compilación

- **Modo obligatorio: bus de datos de 32 bits** (configuración por defecto, `DATA_BUS_WIDTH_8` sin definir). En este modo la dirección es de 5 bits, se usa `wb_sel_i` para seleccionar el byte, y están disponibles los registros de depuración Debug 1 y Debug 2.
- **Variante opcional (puntos extra): bus de 8 bits**, compilando con `+define+DATA_BUS_WIDTH_8`. Como es un parámetro de compilación, no puede aleatorizarse en tiempo de ejecución; el ambiente debe soportar ambas variantes sin cambios de código, solo con un `define` y un objeto de configuración.
- `UART_HAS_BAUDRATE_OUTPUT` es opcional; si lo habilitan, deben verificar `baud_o`.
- Todos los archivos del RTL incluyen `uart_defines.v`; agreguen `+incdir+` al comando de VCS.

### 3.3 Interfaces del DUT

| Interfaz | Señales | Protocolo |
|---|---|---|
| Bus de sistema | `wb_clk_i`, `wb_rst_i`, `wb_adr_i`, `wb_dat_i`, `wb_dat_o`, `wb_we_i`, `wb_stb_i`, `wb_cyc_i`, `wb_sel_i`, `wb_ack_o` | Wishbone Rev. B, esclavo, ciclos simples de lectura y escritura |
| Interrupción | `int_o` | Nivel, activa en alto |
| Serie | `stx_pad_o`, `srx_pad_i` | UART asíncrono: 5 a 8 bits, paridad par, impar, *stick* o ninguna, 1, 1.5 o 2 bits de parada, *break* |
| Módem | `rts_pad_o`, `dtr_pad_o`, `cts_pad_i`, `dsr_pad_i`, `ri_pad_i`, `dcd_pad_i` | Niveles estáticos con detección de cambios (deltas) |
| Opcional | `baud_o` | 16 × tasa de baudios, solo con `UART_HAS_BAUDRATE_OUTPUT` |

### 3.4 Mapa de registros (resumen)

| Dir. | DLAB = 0, lectura | DLAB = 0, escritura | DLAB = 1 |
|---|---|---|---|
| 0 | RBR, salida de la FIFO de recepción | THR, entrada de la FIFO de transmisión | DLL, byte bajo del divisor |
| 1 | IER | IER | DLM, byte alto del divisor |
| 2 | IIR | FCR | igual que DLAB = 0 |
| 3 | LCR | LCR | LCR |
| 4 | MCR (ver 3.5) | MCR | MCR |
| 5 | LSR | — | LSR |
| 6 | MSR | — | MSR |
| 7 | ver 3.5 | ver 3.5 | ver 3.5 |
| 8 | Debug 1 (32 bits, solo lectura) | — | Debug 1 |
| 12 | Debug 2 (32 bits, solo lectura) | — | Debug 2 |

Los registros tienen efectos laterales que el modelo RAL debe representar: lecturas que limpian bits (LSR, MSR, IIR sobre la interrupción THRE), escrituras a FIFO (THR) y lecturas que extraen de FIFO (RBR), y campos de solo escritura (FCR). La tasa de baudios es `f_clk / (16 × DL)`; con DL = 0 el UART no transmite ni recibe.

### 3.5 Puntos que su plan de pruebas debe aclarar

La especificación y el RTL no coinciden en todos los detalles, y el bugtracker tiene reportes abiertos. Antes de escribir su modelo de referencia, revisen al menos estos puntos y documenten en el plan qué comportamiento consideran correcto y por qué:

- Si existe o no un registro *scratch* en la dirección 7.
- Si el MCR se puede leer de vuelta.
- La polaridad de las salidas `rts_pad_o` y `dtr_pad_o` respecto a los bits del MCR, y la de los bits 7:4 del MSR respecto a las entradas de módem.
- La condición exacta en que se activa TERI (MSR bit 2).
- La decodificación de dirección cuando `wb_sel_i` no tiene exactamente un bit activo en el modo de 32 bits.
- El comportamiento con 1.5 o 2 bits de parada, y qué bit de parada verifica el receptor.

Cuando su ambiente detecte una discrepancia, deben reportarla en el informe final con: escenario que la produce, semilla y plusargs para reproducirla, comportamiento esperado según la especificación, comportamiento observado y su recomendación.

> **IMPORTANTE**
> No modifiquen el RTL para que las pruebas pasen. Un error real se documenta y, si bloquea la cobertura, se excluye con justificación.

---

## 4. Filosofía de pruebas: una prueba base que lo cubre todo

Toda la regresión del proyecto se construye con **una sola prueba**, `uart_base_test`, más semillas y archivos de plusargs. No se aceptan pruebas dirigidas escritas como clases nuevas con estímulo propio.

### 4.1 Requisito de completitud

Con los valores por defecto de todas las restricciones, la prueba base debe poder generar **cualquier configuración legal del DUT y cualquier tipo de tráfico que soporte**. Formalmente: para cada *bin* alcanzable de su modelo de cobertura, la probabilidad de alcanzarlo con una semilla al azar debe ser mayor que cero. Así, con un número infinito de semillas, la prueba base alcanzaría en teoría 100 % de cobertura.

Esto implica, como mínimo, que la prueba base aleatorice:

- **Configuración de línea:** longitud de carácter (5 a 8), bits de parada, paridad (deshabilitada, par, impar, *stick* 0 y *stick* 1) y divisor DL.
- **Configuración de FIFO e interrupciones:** nivel de disparo (1, 4, 8, 14), limpieza de FIFOs, cada bit de IER y combinaciones.
- **Modo de operación:** normal o *loopback*; salidas de módem (DTR, RTS, OUT1, OUT2); control de *break*.
- **Tráfico de transmisión:** escrituras a THR en ráfagas de longitud variable, incluyendo llenar y desbordar la FIFO de 16 posiciones.
- **Tráfico de recepción:** caracteres válidos y con errores inyectados por el agente serie: error de paridad, error de trama, condición de *break*, *glitches* en la línea y desajuste de tasa de baudios dentro y fuera de tolerancia.
- **Señales de módem:** cambios en CTS, DSR, RI y DCD en cualquier momento.
- **Estilo de servicio del software:** por interrupciones o por sondeo (*polling*), con retrasos aleatorios en la atención, para provocar desbordamiento (*overrun*) y la indicación de *timeout*.
- **Accesos a registros:** lecturas y escrituras a todas las direcciones, incluyendo reconfiguración en medio del tráfico y accesos con DLAB = 1.
- **Reset:** reset asíncrono en momentos aleatorios, controlado por un plusarg (deshabilitado por defecto si así lo justifican).

Ninguna restricción por defecto puede llevar la probabilidad de un escenario legal a cero. Si por tiempo de simulación necesitan acotar un rango (por ejemplo DL entre 1 y 16 por defecto), la cola completa del rango debe seguir siendo alcanzable con una probabilidad pequeña, y debe existir un plusarg que la amplíe. Deben justificar en el plan cada uno de estos acotamientos.

### 4.2 Casos de esquina por plusargs

Los casos de esquina **no** se escriben como pruebas nuevas: se obtienen corriendo la misma prueba base con plusargs que cambian las restricciones de aleatorización. Por ejemplo, "desbordamiento de la FIFO de recepción con nivel de disparo 14 y 5 bits por carácter" es una línea de la regresión:

```
./simv +UVM_TESTNAME=uart_base_test +ntb_random_seed=1234 \
       -f tests/rx_overrun_tl14_5bit.args
```

Reglas de diseño obligatorias:

1. **Un único punto de lectura.** Los plusargs se leen en un solo lugar (por ejemplo, un método `parse_plusargs()` en la clase de configuración, usando `uvm_cmdline_processor`). Ningún driver, monitor ni secuencia llama a `$value$plusargs` directamente.
2. **Todo pasa por objetos de configuración.** Cada valor leído se guarda en un campo *knob* de un objeto de configuración (`uart_env_cfg`, `wb_agent_cfg`, `uart_ser_agent_cfg`, `modem_agent_cfg`, `uart_scb_cfg`, `uart_cov_cfg`, etc.), y esos objetos se publican con `uvm_config_db#(...)::set` durante `build_phase`.
3. **Disponibles en todos los componentes.** Agentes, drivers, monitores, secuenciadores, secuencias, scoreboard, predictor y colectores de cobertura obtienen su objeto con `uvm_config_db#(...)::get` y usan sus *knobs*. Las secuencias lo obtienen a través de su secuenciador (`get_sequencer()` o `p_sequencer`).
4. **Restricciones parametrizadas por knobs.** Cada restricción usa rangos o pesos tomados de los *knobs*, no constantes mágicas. Los valores por defecto cumplen el requisito de completitud de 4.1.
5. **Convención de nombres.** `+UART_<BLOQUE>_<KNOB>=<valor>`, por ejemplo `+UART_LCR_WLS_WEIGHTS=0,0,0,1` o `+UART_SER_PARITY_ERR_PCT=30`. El plan debe incluir la tabla completa de plusargs.
6. **Trazabilidad.** Al inicio de cada simulación, el ambiente imprime todos los *knobs* con su valor y su origen (por defecto o plusarg), para poder reproducir cualquier corrida con la semilla y el archivo de argumentos.

Patrón sugerido (orientativo, no obligatorio):

```systemverilog
class uart_line_cfg extends uvm_object;
  `uvm_object_utils(uart_line_cfg)
  rand bit [1:0]  wls;            // 5..8 bits
  rand bit        stb, pen, eps, sp;
  rand bit [15:0] dl;
  // knobs (no aleatorios)
  int unsigned wls_w[4]  = '{1,1,1,1};
  int unsigned dl_min = 1, dl_max_fast = 16, dl_max = 16'hFFFF;
  int unsigned dl_tail_pct = 2;   // probabilidad de explorar la cola

  constraint c_wls { wls dist { 0 := wls_w[0], 1 := wls_w[1],
                                2 := wls_w[2], 3 := wls_w[3] }; }
  constraint c_dl  { dl dist { [dl_min:dl_max_fast]   :/ (100 - dl_tail_pct),
                               [dl_max_fast+1:dl_max] :/ dl_tail_pct }; }

  function void parse_plusargs();
    uvm_cmdline_processor clp = uvm_cmdline_processor::get_inst();
    string v;
    if (clp.get_arg_value("+UART_LCR_DL_MAX=", v)) dl_max = v.atoi();
    // ...
  endfunction
endclass
```

---

## 5. Requisitos de la arquitectura del ambiente

Cada grupo propone su propia arquitectura y la justifica a partir de su plan de pruebas; los elementos de esta sección son el **mínimo obligatorio**. El diagrama de 5.4 muestra una arquitectura de referencia, no la única válida.

### 5.1 Componentes obligatorios

| Componente | Requisitos mínimos |
|---|---|
| Agente Wishbone (activo) | Driver maestro Wishbone con retardos aleatorios entre transacciones y en `stb`; monitor que publica cada transacción por un `uvm_analysis_port`; manejo de `wb_sel_i` en modo de 32 bits |
| Agente serie UART (activo y pasivo) | Driver que transmite hacia `srx_pad_i` con cualquier formato de línea e inyección de errores (paridad, trama, *break*, *glitch*, desviación de baudios); monitor de `stx_pad_o` que reconstruye caracteres; monitor de `srx_pad_i` |
| Agente de módem | Driver de `cts`, `dsr`, `ri`, `dcd` con cambios aleatorios; monitor de las cuatro entradas y de `rts`, `dtr` |
| Monitor de interrupción | Observa `int_o` y lo correlaciona con IER, IIR y el estado del modelo |
| Secuenciador virtual | Coordina los secuenciadores Wishbone, serie y de módem; es donde corre la secuencia principal de la prueba base |
| Secuencias | Biblioteca de secuencias de registros (sobre el RAL), de tráfico TX, de tráfico RX, de módem, de servicio de interrupciones y de reconfiguración; una secuencia virtual principal que las combina aleatoriamente |
| Scoreboard y modelo de referencia | Compara datos TX (THR contra línea serie), datos RX (línea serie contra RBR), estado de LSR, MSR, IIR e `int_o`; modela FIFOs, niveles de disparo, *overrun*, *timeout* y prioridades de interrupción |
| Aserciones SVA | Módulo o interfaz enlazado con `bind`: protocolo Wishbone (estabilidad de señales mientras `cyc && stb` sin `ack`, `ack` en un ciclo acotado, ausencia de X), protocolo serie (bit de inicio, ancho de bit según DL, línea en reposo en 1, `stx_pad_o` en 1 durante *loopback*), señales de módem en *loopback*; cada propiedad con su `cover property` |
| RAL | Modelo de registros generado a mano o con `ralgen`, con mapas para DLAB = 0 y DLAB = 1 (o la estrategia que justifiquen), adaptador `reg2bus` / `bus2reg` para Wishbone, predictor explícito (`uvm_reg_predictor`) conectado al monitor Wishbone, acceso por puerta delantera y por puerta trasera (`hdl_path` a `uart_top.regs.*`) |
| Cobertura funcional | `covergroup` de configuración, de tráfico, de errores, de interrupciones, de módem y de registros, con cruces relevantes; muestreados desde monitores, el RAL o el scoreboard, nunca desde el driver |
| Objetos de configuración | Uno por agente y uno por ambiente, con los *knobs* de la sección 4 |

### 5.2 Requisitos del RAL

- Modelar los campos con su acceso correcto (`RW`, `RO`, `WO`, `RC` o con *callbacks* para efectos laterales) y sus valores de reset según la especificación.
- Resolver el problema de los registros que comparten dirección (RBR/THR/DLL, IER/DLM, IIR/FCR) y explicar la solución en el plan.
- Usar la puerta trasera al menos para: verificación de valores de reset, comprobación de que una escritura por puerta delantera llegó al registro interno, y lectura de estado sin efectos laterales.
- Correr las secuencias integradas de UVM que apliquen (`uvm_reg_hw_reset_seq`, `uvm_reg_bit_bash_seq`, `uvm_reg_access_seq`), excluyendo con `NO_REG_TESTS` u opciones equivalentes los registros donde no aplican y justificando cada exclusión.

### 5.3 Requisitos generales de calidad

- Cero advertencias de compilación propias del ambiente; `UVM_ERROR` y `UVM_FATAL` en cero en una corrida que pasa.
- Uso de la *factory* para todos los componentes y objetos, de modo que un plusarg `+uvm_set_type_override` permita sustituir cualquier pieza.
- Fin de prueba con objeciones, sin `#delay` arbitrarios; un *drain time* justificado.
- Script de compilación y regresión (Makefile o Python) que corre la regresión completa y fusiona la cobertura con `urg`.

### 5.4 Arquitectura de referencia

**Una sola prueba base configura todo el ambiente por `config_db`.**

```
┌──────────────────────────────────────────────────────────────────────┐
│ uart_base_test                                                       │
│ parse_plusargs() → knobs en objetos de configuración                 │
│   → uvm_config_db::set para todos los componentes                    │
└──────────────────────────────────┬───────────────────────────────────┘
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│ uart_env                                                             │
│                                                                      │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────────┐  │
│  │ Virtual sequencer│ │ Modelo RAL       │ │ Objetos de           │  │
│  │ corre la sec.    │ │ reg_block con    │ │ configuración        │  │
│  │ principal        │ │ mapas DLAB 0/1   │ │ knobs leídos de      │  │
│  │ coordina WB,     │ │ adaptador WB,    │ │ plusargs, publicados │  │
│  │ serie y módem    │ │ puerta delantera │ │ en uvm_config_db,    │  │
│  │ lanza secuencias │ │ puerta trasera:  │ │ visibles en todo el  │  │
│  │ del RAL          │ │ uart_top.regs    │ │ ambiente             │  │
│  └────────┬─────────┘ └──────────────────┘ └──────────────────────┘  │
│           │  secuencias → secuenciadores                             │
│     ┌─────┴────────────────┬───────────────────────┐                 │
│     ▼                      ▼                       ▼                 │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────────┐  │
│  │ Agente Wishbone  │ │ Agente serie UART│ │ Agente módem + int_o │  │
│  │ driver maestro   │ │ driver a srx_pad_i│ │ driver de cts, dsr,  │  │
│  │ con retardos     │ │ con errores      │ │ ri, dcd              │  │
│  │ monitor →        │ │ monitor de       │ │ monitor de rts y dtr │  │
│  │ analysis port    │ │ stx_pad_o        │ │ monitor de           │  │
│  │ maneja wb_sel_i  │ │ monitor de       │ │ interrupción         │  │
│  │ (32 bits)        │ │ srx_pad_i        │ │                      │  │
│  └────────┬─────────┘ └────────┬─────────┘ └──────────┬───────────┘  │
│           └──────── analysis ports ──────────┬─────────┘              │
│     ┌──────────────────────┬─────────────────┴────┐                  │
│     ▼                      ▼                      ▼                  │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────────┐  │
│  │ Predictor RAL    │ │ Scoreboard       │ │ Cobertura funcional  │  │
│  │ uvm_reg_predictor│ │ modelo de        │ │ configuración,       │  │
│  │ actualiza el     │ │ referencia       │ │ tráfico, errores,    │  │
│  │ espejo del RAL   │ │ compara TX, RX,  │ │ interrupciones,      │  │
│  │ con lo observado │ │ LSR, IIR, MSR y  │ │ módem y registros    │  │
│  │ en el bus        │ │ la línea int_o   │ │                      │  │
│  └──────────────────┘ └──────────────────┘ └──────────────────────┘  │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │ interfaces virtuales (wb_if, uart_if, modem_if)
                                   ▼
        ┌──────────────────────────────────┐   ┌───────────────────────┐
        │ uart_top (DUT)                   │───│ Aserciones SVA (bind) │
        │ Wishbone · serie stx/srx ·       │   │ Wishbone, serie,      │
        │ módem · int_o                    │   │ loopback              │
        └──────────────────────────────────┘   └───────────────────────┘
```

*La prueba base publica la configuración; el secuenciador virtual estimula por los tres agentes y todos los monitores alimentan al predictor, al scoreboard y a la cobertura.*

*(Diagrama redibujado en texto a partir del original del enunciado.)*

---

## 6. Análisis de cobertura y cierre

La meta es **al menos 95 % en cobertura funcional y al menos 95 % en cada métrica de cobertura de código** (línea, condición, rama, FSM y *toggle*), medidas sobre la regresión completa fusionada con `urg`. Si no la alcanzan, la nota de esta parte depende de la calidad de la justificación.

### 6.1 Cómo medir

- Compilar con `-cm line+cond+branch+fsm+tgl` y `-cm_hier` limitado a la jerarquía del DUT (`uart_top` y sus instancias); el ambiente no cuenta en la cobertura de código.
- Ejecutar cada corrida con `-cm_name <prueba>_<semilla>` y fusionar con `urg -dir *.vdb -dbname merged -report cov_report`.
- Las exclusiones se hacen únicamente con archivos de exclusión de URG / Verdi (`.el`), versionados en el repositorio, con un comentario de justificación por cada elemento excluido.

### 6.2 Proceso obligatorio

1. **Línea base.** Correr solo la prueba base con valores por defecto y N semillas (N ≥ 200, o lo que justifiquen por tiempo). Graficar cobertura funcional y de código contra número de semillas: la curva debe mostrar cómo se satura.
2. **Análisis de huecos.** Clasificar cada *bin* o elemento de código no cubierto en una de cuatro categorías:
   - a. **Alcanzable, baja probabilidad:** se cierra con un archivo de plusargs nuevo que cambia pesos o rangos.
   - b. **Falta capacidad de estímulo:** el ambiente no sabe generarlo; se corrige el ambiente y se explica por qué la prueba base no cumplía el requisito de completitud.
   - c. **Inalcanzable:** código muerto, constante, rama `default` imposible, lógica del modo de bus no compilado; se excluye con justificación.
   - d. **Bloqueado por un error del DUT:** se documenta el error (sección 3.5) y se excluye o se deja abierto con justificación.
3. **Pruebas adicionales.** Para cada hueco de la categoría a, proponer un archivo `.args` con nombre descriptivo, el objetivo de cobertura que persigue y cuántas semillas necesita.
4. **Iteración.** Repetir hasta llegar a la meta o hasta que todo hueco restante esté en las categorías c o d.
5. **Informe de cierre.** Tabla de huecos finales con su categoría y justificación, cobertura por métrica antes y después de las pruebas adicionales, y lista de *bins* que solo se alcanzan con plusargs (indicador de restricciones por defecto demasiado estrechas).

### 6.3 Qué no se acepta

- Bajar la meta eliminando *bins* del modelo de cobertura sin justificación, o usar `option.weight = 0` e `ignore_bins` para esconder huecos alcanzables.
- Excluir código alcanzable solo porque no lo cubrieron.
- Pruebas dirigidas escritas fuera del mecanismo de plusargs.
- Cobertura muestreada en el driver (mide lo que se intentó, no lo que ocurrió).

---

## 7. Entregables y cronograma

El proyecto tiene tres entregas evaluadas y una entrevista individual: la propuesta al final de la semana 2 del proyecto, el avance al final de la semana 4 del proyecto, y la entrega final el **Lunes de semana 18**, seguida de las entrevistas. Las semanas del proyecto (S1, S2, ...) se cuentan desde la publicación del enunciado; las fechas exactas de E1 y E2 se publican en el sistema del curso; las entregas se hacen con una etiqueta Git (`entrega1`, `entrega2`, `final`) más los documentos en PDF.

| Entrega | Semana | Contenido obligatorio |
|---|---|---|
| E1. Propuesta | Fin de la semana 2 del proyecto | Plan de pruebas según el machote de la sección 9; arquitectura propuesta con diagrama; tabla completa de *knobs* y plusargs; modelo de cobertura funcional (covergroups, coverpoints, bins y cruces); lista de aserciones; estrategia RAL; distribución del trabajo entre los tres integrantes; RTL compilando en VCS. Defensa oral de 20 minutos. |
| E2. Avance | Fin de la semana 4 del proyecto | Ambiente compilando y corriendo la prueba base con al menos 20 semillas sin errores falsos; agentes Wishbone y serie completos; RAL con `uvm_reg_hw_reset_seq` pasando por puerta delantera y trasera; scoreboard de TX y RX funcionando; primer reporte de cobertura de URG. Documento corto (≤ 4 páginas) con el estado, problemas encontrados y plan para las semanas restantes. |
| E3. Final | Lunes de semana 18 | Código completo en el repositorio con script de regresión; informe final (plan actualizado, arquitectura final, resultados de cobertura con la curva de línea base, análisis de huecos, pruebas adicionales en `.args`, exclusiones justificadas, errores del DUT encontrados); reporte HTML de URG; presentación y demostración en vivo de 25 minutos con participación de los tres integrantes. |
| Entrevista individual | Semana 18, tras E3 | Sesión individual de 20 a 30 minutos con cada integrante sobre el código entregado en la etiqueta `final`. Ver sección 8.2. |

### Plan semanal sugerido

**Tres entregas y la entrevista: la entrega final es el Lunes de semana 18.**

| Fase | Semanas | Contenido |
|---|---|---|
| Propuesta | S1–S2 | **S1:** leer la especificación y compilar el RTL en VCS. **S2:** plan de pruebas, arquitectura y knobs. |
| Construcción | S3–S4 | **S3:** interfaces, agentes y modelo RAL. **S4:** scoreboard, módem y aserciones SVA. |
| Cobertura y cierre | S5 en adelante | **S5:** covergroups, regresión, línea base. **S6:** análisis de huecos, archivos `.args`. **Final:** exclusiones, informe, demo. |

Hitos: **E1 · Propuesta (25 %)** fin de la semana 2 del proyecto · **E2 · Avance (15 %)** fin de la semana 4 del proyecto · **E3 · Final (60 %) + entrevista** Lunes de semana 18.

La fase de cobertura va desde la semana 5 del proyecto hasta el Lunes de semana 18 porque el cierre al 95 % suele tomar más iteraciones de lo previsto; el grupo que termine la construcción antes debe adelantar la línea base.

---

## 8. Evaluación

La nota del grupo se reparte 25 % en la propuesta, 15 % en el avance y 60 % en la entrega final. La nota individual de cada integrante es la nota del grupo, siempre que apruebe la entrevista individual de la sección 8.2.

### 8.1 Rúbrica de la nota del grupo

| Rubro | Entrega | Peso | Criterio de excelencia |
|---|---|---|---|
| Plan de pruebas | E1 | 15 % | Cada característica de la especificación tiene un ítem verificable, un mecanismo de verificación y una métrica; los puntos de la sección 3.5 están discutidos |
| Arquitectura y estrategia de estímulo | E1 | 10 % | Prueba base con argumento claro de completitud; tabla de *knobs* coherente; RAL y cobertura bien diseñados |
| Estado del avance | E2 | 15 % | Se cumplen los puntos de E2 sin errores falsos; problemas identificados con plan realista |
| Implementación del ambiente | E3 | 20 % | Todos los componentes de la sección 5 funcionan; código limpio, reutilizable y con *factory* |
| Mecanismo de plusargs y configuración | E3 | 10 % | Cumple las seis reglas de 4.2; cualquier corrida se reproduce con semilla y archivo `.args` |
| RAL completo | E3 | 10 % | Predictor, adaptador, puerta delantera y trasera, secuencias integradas con exclusiones justificadas |
| Cobertura y análisis de cierre | E3 | 15 % | ≥ 95 % en cada métrica, o huecos clasificados y justificados con rigor; curva de línea base; pruebas adicionales bien motivadas |
| Errores del DUT reportados | E3 | 5 % | Reportes reproducibles y bien argumentados contra la especificación |
| Presentación y demostración | E3 | — | Incluida en los rubros anteriores; los tres integrantes presentan |

**Puntos extra (hasta 10 %):** soporte de la variante de bus de 8 bits sin cambios de código; verificación de `baud_o`; aserciones formales corridas con VC Formal sobre la interfaz Wishbone.

### 8.2 Entrevista individual (requisito de aprobación)

> **REGLA ELIMINATORIA**
> Cada integrante tiene una entrevista individual sobre el código que el grupo presentó. **Si el integrante demuestra que no entiende el código, su nota del proyecto es cero**, sin importar la nota del grupo. La nota de los otros integrantes no se ve afectada por el resultado de un compañero.

**Formato.** La entrevista se hace en la semana 18, después de la entrega E3 del Lunes de semana 18, con cada integrante por separado y sin presencia de los demás miembros del grupo. Dura entre 20 y 30 minutos. El estudiante trabaja en su propia cuenta, con el repositorio en la etiqueta `final`, el simulador y el editor; no puede consultar a sus compañeros ni a terceros durante la sesión. No asistir a la entrevista sin justificación válida equivale a no aprobarla.

**Qué se revisa.** El profesor elige las partes del código; el estudiante no decide de qué se le pregunta. Las preguntas cubren componentes escritos por cualquiera de los tres integrantes. Como mínimo se le pedirá:

1. Explicar la arquitectura del ambiente y seguir el recorrido de una transacción, desde la secuencia virtual hasta el scoreboard y la cobertura.
2. Explicar en detalle al menos dos componentes elegidos por el profesor (por ejemplo, el adaptador del RAL, el modelo de interrupciones del scoreboard o una restricción de la configuración), incluyendo por qué está escrito así.
3. Hacer en vivo un cambio pequeño y ejecutarlo: agregar un *knob* con su plusarg y usarlo en una restricción, agregar un *bin* o un cruce, o modificar una aserción.
4. Interpretar un resultado: un mensaje de error del scoreboard, una falla de aserción o un hueco en el reporte de URG, y decir cómo lo investigaría.

**Criterio.** El resultado es *aprueba* o *no aprueba*. Se considera que el integrante **no entiende el código** si no puede explicar el propósito y el funcionamiento de las partes consultadas, no logra hacer el cambio pedido ni describir cómo lo haría, o da explicaciones contradictorias con lo que el código hace. No se exige recordar cada línea de memoria: se puede leer el código durante la entrevista. El historial de commits del repositorio se usa como evidencia de contexto, pero no reemplaza la entrevista.

---

## 9. Machote del plan de pruebas

El plan de pruebas de la entrega E1 se escribe en un documento ODT (LibreOffice Writer) que contenga las tablas de esta sección, en el mismo orden. Pueden descargar el machote ya armado, `machote_plan_pruebas_uart16550.odt`, o reproducir las tablas en su propio documento.

> **CÓMO LLENARLO**
> Llenen todas las tablas. Las filas en gris son ejemplos que muestran el nivel de detalle esperado: reemplácenlas por las suyas. Pueden agregar filas y secciones, pero no eliminar ninguna. Entreguen el ODT y una copia en PDF.

*Nota: la numeración de los títulos siguientes (Portada, 1 a 17) es la propia del machote y es independiente de la numeración de este enunciado. Las filas marcadas "(ejemplo)" son las filas en gris del original.*

### Portada

| Campo | Valor |
|---|---|
| Proyecto | Verificación del UART 16550 con UVM |
| Integrante 1 | |
| Integrante 2 | |
| Integrante 3 | |
| Versión del plan | |
| Fecha | |
| Repositorio Git | |
| Etiqueta Git | entrega1 |

### 1. Alcance

| Campo | Valor |
|---|---|
| Versión del RTL verificada (commit o revisión SVN) | |
| Configuración de compilación (bus de 32 bits; variante de 8 bits sí/no) | |
| Frecuencia de reloj en simulación y rango de DL soportado | |
| Funcionalidad fuera de alcance y justificación | |

### 2. Documentos de referencia

| Documento | Versión | Enlace o ubicación |
|---|---|---|
| UART IP Core Specification *(ejemplo)* | Rev. 0.6 | docs/UART_spec.pdf |
| | | |
| | | |

### 3. Interpretación de la especificación

Una fila por cada ambigüedad o discrepancia entre la especificación y el RTL (sección 3.5 del enunciado).

| ID | Tema | La especificación dice | El RTL hace | Comportamiento que modelamos | Justificación |
|---|---|---|---|---|---|
| AMB-01 *(ejemplo)* | Registro scratch en la dirección 7 | ... | ... | ... | ... |
| | | | | | |
| | | | | | |

### 4. Lista de características

| ID | Característica | Fuente (sección de la especificación) | Prioridad (alta, media, baja) |
|---|---|---|---|
| F-LCR-01 *(ejemplo)* | Longitud de carácter de 5, 6, 7 y 8 bits | Line Control Register, bits 1:0 | Alta |
| F-INT-03 *(ejemplo)* | Interrupción de timeout tras 4 tiempos de carácter | Interrupt Identification Register | Alta |
| | | | |
| | | | |

### 5. Matriz de verificación

Una o más filas por cada característica de la sección 4.

| ID ítem | Característica | Qué se verifica | Mecanismo (scoreboard, SVA, RAL, cobertura) | Métrica de cierre (coverpoint o aserción) | Plusargs que lo ejercitan *(ver nota)* |
|---|---|---|---|---|---|
| V-LCR-01 *(ejemplo)* | F-LCR-01 | Datos TX y RX correctos con cada longitud | Scoreboard TX y RX | cg_line_cfg.cp_wls × cp_dir | +UART_LC… *(texto cortado en el PDF)* |
| V-INT-03 *(ejemplo)* | F-INT-03 | IIR[3:0] = 4'hC con datos bajo el nivel de disparo y sin actividad | Modelo de interrupciones y SVA | cg_int.cp_iir_id[TIMEOUT] | +UART_SV… *(texto cortado en el PDF)* |
| | | | | | |
| | | | | | |

> **Nota de transcripción:** en el PDF fuente esta tabla estaba más ancha que la página (tenía barra de desplazamiento horizontal), por lo que la última columna y posiblemente otras a su derecha quedaron cortadas. El encabezado visible de la última columna empieza con "Plusargs q…"; lo completé como "Plusargs que lo ejercitan" por inferencia. Conviene verificarlo contra el machote `.odt` oficial.

### 6. Estrategia de estímulo: prueba base

#### 6.1 Espacio de aleatorización

| Variable aleatoria | Objeto de configuración | Rango legal | Distribución por defecto | Knobs |
|---|---|---|---|---|
| lcr.wls *(ejemplo)* | uart_line_cfg | 0 a 3 | Uniforme | wls_w[4] |
| dl *(ejemplo)* | uart_line_cfg | 1 a 65535 | 98 % en 1 a 16, 2 % en el resto | dl_max_fast, dl_max, dl_tail_pct |
| | | | | |
| | | | | |

#### 6.2 Argumento de completitud

| Bin o grupo de bins | Por qué su probabilidad es mayor que cero con los valores por defecto | Plusarg que lo acelera |
|---|---|---|
| cg_err.cp_oe × cp_tl *(ejemplo)* | La FIFO RX se llena si el retraso de servicio aleatorio supera el tiempo de 16 caracteres; el rango por defecto del retraso lo permite | +UART_SW_SERVICE_DELAY_MIN |
| | | |
| | | |

#### 6.3 Secuencia virtual principal

*Describa o escriba en pseudocódigo el flujo de la prueba base: reset, configuración, mezcla de tráfico, reconfiguraciones, servicio de interrupciones y fin de prueba.*

### 7. Tabla de plusargs

| Plusarg | Tipo y rango | Valor por defecto | Componentes que lo usan | Objeto de configuración | Efecto |
|---|---|---|---|---|---|
| +UART_SER_PARITY_ERR_PCT *(ejemplo)* | Entero 0 a 100 | 5 | Driver serie, scoreboard | uart_ser_agent_cfg | Porcentaje de caracteres RX con paridad corrupta |
| | | | | | |
| | | | | | |

### 8. Casos de esquina planificados

| ID | Escenario | Archivo .args | Plusargs | Bins objetivo | Semillas |
|---|---|---|---|---|---|
| CE-01 *(ejemplo)* | Overrun de la FIFO RX con nivel de disparo 14 | rx_overrun_tl14.args | +UART_FCR_TL_WEIGHTS=0,0,0,1 +UART_SW_SERVICE_DELAY_MIN=... | cg_err.cp_oe × cp_tl | 20 |
| | | | | | |
| | | | | | |

### 9. Arquitectura del ambiente

#### 9.1 Diagrama

*Inserte aquí el diagrama del ambiente: prueba, ambiente, agentes, secuenciador virtual, RAL, scoreboard, cobertura y SVA.*

#### 9.2 Componentes

| Componente | Clase UVM base | Responsabilidad | Puertos TLM |
|---|---|---|---|
| uart_wb_agent *(ejemplo)* | uvm_agent | Maneja y observa la interfaz Wishbone | ap (uvm_analysis_port) |
| | | | |
| | | | |

#### 9.3 Flujo de configuración

| Objeto de configuración | Ruta en uvm_config_db | Lo publica | Lo obtienen |
|---|---|---|---|
| wb_agent_cfg *(ejemplo)* | uvm_test_top.env.wb_agt* | uart_base_test | Driver, monitor y secuencias Wishbone |
| | | | |
| | | | |

### 10. Modelo de referencia y scoreboard

| Qué se predice | Fuente de la predicción | Momento de la comparación | Tolerancia |
|---|---|---|---|
| Datos TX *(ejemplo)* | Escrituras a THR (monitor Wishbone) | Al reconstruir el carácter en stx_pad_o | Ninguna |
| **Datos RX** | | | |
| **LSR** | | | |
| **IIR** | | | |
| **MSR** | | | |
| **int_o** | | | |
| | | | |
| | | | |

### 11. Aserciones

| ID | Interfaz | Propiedad (en palabras) | Tipo (assert, assume, cover) | Ítem del plan |
|---|---|---|---|---|
| A-WB-01 *(ejemplo)* | Wishbone | adr, dat_i, we y sel estables mientras cyc y stb están activos y no hay ack | assert y cover | V-WB-01 |
| | | | | |
| | | | | |

### 12. RAL

#### 12.1 Registros y campos

| Registro | Dirección | DLAB | Campo | Bits | Acceso | Reset | Ruta de puerta trasera |
|---|---|---|---|---|---|---|---|
| LCR *(ejemplo)* | 3 | 0 y 1 | WLS | 1:0 | RW | 2'b11 | uart_top.regs.lcr |
| | | | | | | | |
| | | | | | | | |

#### 12.2 Decisiones de modelado

| Tema | Decisión | Justificación |
|---|---|---|
| Registros con dirección compartida (DLAB) | | |
| Predictor y adaptador: conexión y política de predicción | | |
| Efectos laterales (lectura que limpia, FIFOs) | | |
| Secuencias integradas que se correrán y exclusiones | | |

### 13. Modelo de cobertura funcional

| Covergroup | Dónde se muestrea | Coverpoints | Cruces | Bins ilegales o ignorados (justificación) |
|---|---|---|---|---|
| cg_line_cfg *(ejemplo)* | Monitor Wishbone al escribir LCR | wls, stb, pen, eps, sp, bc | wls × stb × paridad | Stick sin paridad habilitada: ignorado, no tiene efecto |
| | | | | |
| | | | | |

### 14. Cobertura de código

| Métrica | Jerarquía incluida | Meta | Exclusiones previstas y justificación |
|---|---|---|---|
| Línea | | ≥ 95 % | |
| Condición | | ≥ 95 % | |
| Rama | | ≥ 95 % | |
| FSM | | ≥ 95 % | |
| Toggle | | ≥ 95 % | |

### 15. Criterios de cierre

| Criterio | Meta | Cómo se mide |
|---|---|---|
| Cobertura funcional | ≥ 95 % | |
| Cada métrica de cobertura de código | ≥ 95 % | |
| UVM_ERROR en la regresión | 0, salvo errores del DUT documentados | |
| Aserciones con cover alcanzado | 100 % | |
| | | |

### 16. Riesgos y mitigación

| Riesgo | Impacto | Mitigación |
|---|---|---|
| | | |
| | | |

### 17. Distribución del trabajo

Cada integrante es responsable principal de algunos componentes, pero los tres deben entender todo el ambiente (entrevista individual, sección 8.2 del enunciado).

| Componente o tarea | Responsable principal | Revisor (otro integrante) | Semana |
|---|---|---|---|
| | | | |
| | | | |

---

## 10. Referencias

- UART 16550 core, OpenCores: página del proyecto, descarga y bugtracker.
- freecores/uart16550, GitHub: espejo del repositorio con RTL, banco de pruebas original y `docs/UART_spec.pdf`.
- UART IP Core Specification, Rev. 0.6.1: especificación en HTML con aclaraciones y lista de errores conocidos del núcleo.
- Accellera, *Universal Verification Methodology (UVM) 1.2 Class Reference* y *UVM 1.2 User's Guide*.
- IEEE 1800-2017, *SystemVerilog Language Reference Manual*, capítulos 16 (aserciones), 18 (aleatorización) y 19 (cobertura funcional).
- OpenCores, especificación del bus Wishbone Rev. B.3, en la sección WISHBONE de OpenCores.
- Synopsys, *VCS User Guide* y *Coverage Technology User Guide* (URG), disponibles en SolvNetPlus con la licencia del curso.

---

*Verificación funcional de circuitos integrados · Enunciado del proyecto UVM · 2026*
*Fuente: tecdigital.tec.ac.cr, EL5811, S-2-2026 (impresión del 20/10/2026).*
