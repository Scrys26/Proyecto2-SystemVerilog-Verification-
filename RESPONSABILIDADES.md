# Responsabilidades del equipo

Proyecto: verificación del UART 16550 con UVM (EL5811).
Este documento define quién es dueño de cada parte del proyecto, quién la revisa y cómo se organiza el trabajo en Git.

| Integrante | Área | Cuenta de Git |
|---|---|---|
| **Eric** | Interfaz Wishbone, infraestructura del RAL, testbench top y regresión | _por completar_ |
| **Diego** | Interfaz serie | _por completar_ |
| **Randy** | Interfaz de módem, interrupciones, env y prueba base | _por completar_ |

---

## 1. Principio de reparto

Se divide por **interfaces del DUT**: Wishbone, serie y módem. Cada responsable es dueño de **su agente completo** y, sobre ese dominio, de:

- su objeto de configuración, con sus *knobs*, restricciones y `parse_plusargs()`;
- sus secuencias y transacciones;
- su sección del scoreboard;
- sus aserciones SVA;
- sus covergroups;
- sus clases de registro del RAL;
- sus ítems del plan de pruebas.

### Sobre los registros y el RAL

Los registros no pertenecen a una interfaz: todos están dentro del DUT y **solo se acceden por Wishbone**. Los agentes serie y módem mueven pines y no tocan registros. Por eso el RAL es **un solo modelo** (`uart_reg_block`) con un adaptador conectado al agente Wishbone.

Aun así, cada registro se relaciona con un dominio por su función, y el reparto de las **clases de registro** sigue esa relación. Las secuencias de serie y módem configuran el DUT a través del RAL (`ral.lcr.write(...)`, `ral.mcr.write(...)`) en lugar de armar transacciones Wishbone a mano.

| Dominio | Registros | Quién escribe sus clases RAL |
|---|---|---|
| Serie | THR, RBR, DLL, DLM, LCR, LSR, FCR (FIFOs) | Diego |
| Módem e interrupciones | MCR, MSR, IER, IIR | Randy |
| Bus | Debug 1, Debug 2, dirección 7 (*scratch*, a discutir en 3.5 del enunciado) | Eric |

> Esta asignación sale del resumen del enunciado (sección 3.4). Debe verificarse contra `doc/UART_spec.pdf` antes de cerrar la sección 12 del plan.

Eric ensambla todo: `reg_block`, mapas DLAB 0/1, adaptador `reg2bus`/`bus2reg`, predictor, puerta trasera (`hdl_path`) y secuencias integradas de UVM.

---

## 2. Anillo de revisión

Nada entra a `develop` sin un PR aprobado por el revisor del dueño.

| Dueño | Revisor |
|---|---|
| Eric | Diego |
| Diego | Randy |
| Randy | Eric |

Excepción: la infraestructura del RAL es extensa y compartida, así que la revisan **los dos** compañeros.

El revisor debe poder explicar el código que aprueba: la entrevista individual cubre todo el ambiente, no solo la parte propia.

---

## 3. Reparto por componente

| Componente | Eric (Wishbone) | Diego (Serie) | Randy (Módem e interrupciones) |
|---|---|---|---|
| Agente | Wishbone: driver con retardos aleatorios, monitor con `analysis_port`, manejo de `wb_sel_i` | Serie: driver hacia `srx_pad_i` con errores (paridad, trama, *break*, *glitch*, baudios), monitor de `stx_pad_o`, monitor de `srx_pad_i` | Módem: driver de `cts/dsr/ri/dcd`, monitor de entradas y de `rts/dtr`, monitor de `int_o` |
| Clases de registro (RAL) | Debug 1/2, dirección 7 | THR, RBR, DLL, DLM, LCR, LSR, FCR | MCR, MSR, IER, IIR |
| RAL (infraestructura) | `reg_block`, mapas DLAB, adaptador, predictor, puerta trasera, secuencias integradas | Revisa | Revisa |
| Scoreboard | Lecturas contra el espejo del RAL | Datos TX/RX, FIFOs, LSR, *overrun* | IIR, prioridades, *timeout*, `int_o`, MSR |
| Aserciones SVA | Protocolo Wishbone | Protocolo serie | Señales de módem en *loopback* |
| Cobertura funcional | Registros y accesos | Configuración de línea, tráfico y errores | Módem e interrupciones |
| Config y plusargs | `wb_agent_cfg` | `uart_ser_agent_cfg` | `modem_agent_cfg` |
| Secuencias | Secuencias de registros sobre el RAL | Tráfico TX y RX | Módem, servicio de interrupciones, reconfiguración |
| Integración | Top del testbench (interfaces virtuales, DUT, `bind`), script de regresión y URG | — | `uart_env`, `uart_env_cfg`, `uart_base_test`, secuenciador virtual |

---

## 4. Config y plusargs

Cada dueño conoce sus parámetros aleatorizables, por eso cada uno escribe la clase de configuración de su agente. El enunciado exige un único punto de lectura (sección 4.2), y se cumple así:

- Cada clase de configuración tiene su `parse_plusargs()`.
- **Solo `uart_base_test` llama** a esos métodos. Ningún driver, monitor ni secuencia lee plusargs directamente.
- Convención de prefijos por dominio: `+UART_WB_*`, `+UART_SER_*`, `+UART_MODEM_*`, `+UART_INT_*`, `+UART_LCR_*`, `+UART_FCR_*`, `+UART_SW_*`.
- En E1, **los tres juntos** definen la convención de nombres y la tabla de plusargs (sección 7 del machote). Randy ensambla `uart_env_cfg`.
- Al inicio de cada simulación se imprimen todos los *knobs* con su valor y origen (regla 6 de 4.2).

### Casos que tocan dos dominios

Los cruces de cobertura y escenarios que mezclan dominios (por ejemplo, nivel de disparo de FIFO × *overrun*, o *loopback* × señales de módem) los define el dueño del dominio principal y los valida el otro. Se listan en las secciones 8 y 13 del machote para que ninguno quede sin dueño.

---

## 5. Trabajo por entrega

### E1: Propuesta (fin de la semana 2)

Plan de pruebas según el machote (portada y secciones 1 a 17). Cada quien llena las filas de su dominio.

| Sección del machote | Eric | Diego | Randy |
|---|---|---|---|
| 3. Interpretación de la especificación | Dirección 7 (*scratch*), decodificación con `wb_sel_i` | Bits de parada (1.5 y 2), qué bit verifica el receptor | Lectura de MCR, polaridad de `rts/dtr` y MSR, condición de TERI |
| 4. Lista de características | Protocolo Wishbone, registros, Debug | Línea, FIFOs, divisor y baudios, errores de recepción | Módem, interrupciones y su prioridad, *loopback* |
| 5. Matriz de verificación | Su dominio | Su dominio | Su dominio |
| 6.1 y 6.2 Aleatorización y completitud | Su dominio | Su dominio | Su dominio |
| 6.3 Secuencia virtual principal | Revisa | Revisa | **Redacta** |
| 7. Tabla de plusargs | Sus filas | Sus filas | Sus filas y la tabla consolidada |
| 8. Casos de esquina | Su dominio | Su dominio | Su dominio |
| 9. Arquitectura (diagrama y flujo de config) | Revisa | Revisa | **Redacta** |
| 9.2 Componentes | Sus componentes | Sus componentes | Sus componentes |
| 10. Modelo de referencia y scoreboard | Lecturas vs. espejo RAL | Datos TX/RX, LSR | IIR, MSR, `int_o` |
| 11. Aserciones | Wishbone | Serie | Módem y *loopback* |
| 12. RAL | **Redacta** 12.2 y sus filas de 12.1 | Sus filas de 12.1 | Sus filas de 12.1 |
| 13. Cobertura funcional | Registros | Línea, tráfico, errores | Módem, interrupciones |
| 14. Cobertura de código | **Redacta** | Revisa | Revisa |
| 15. Criterios de cierre | **Redacta** | Revisa | Revisa |
| Portada, 1, 2, 16, 17 | Todos | Todos | Todos |

Además: RTL compilando en VCS (Eric) y ensayo conjunto de la defensa oral (20 min).

### E2: Avance (fin de la semana 4)

Ambiente compilando y corriendo la prueba base con al menos 20 semillas sin errores falsos.

| Entregable | Responsable | Revisor |
|---|---|---|
| Agente Wishbone completo | Eric | Diego |
| RAL con `uvm_reg_hw_reset_seq` por puerta delantera y trasera | Eric (con las clases de Diego y Randy) | Diego y Randy |
| Top del testbench con interfaces y DUT | Eric | Diego |
| Agente serie completo (driver, monitores) | Diego | Randy |
| Scoreboard de TX y RX | Diego | Randy |
| Agente de módem y monitor de `int_o` | Randy | Eric |
| `uart_env`, `uart_env_cfg`, `uart_base_test`, vseq mínima | Randy | Eric |
| Script de regresión y primer reporte de URG | Eric | Randy |
| Cada cfg con `parse_plusargs()` y *knobs* impresos | Cada dueño | Su revisor |
| Documento de avance (≤ 4 páginas) | Todos | Todos |

### E3: Final (lunes de semana 18)

| Entregable | Responsable | Revisor |
|---|---|---|
| Aserciones Wishbone con `cover property` | Eric | Diego |
| Secuencias RAL y secuencias integradas con exclusiones justificadas | Eric | Diego y Randy |
| Covergroups de registros y accesos | Eric | Diego |
| Reporte de errores del DUT del área de registros y bus | Eric | Diego |
| Regresión completa con fusión de cobertura por URG | Eric | Randy |
| Inyección de errores completa en el agente serie | Diego | Randy |
| Aserciones serie con `cover property` | Diego | Randy |
| Covergroups de línea, tráfico y errores | Diego | Randy |
| Reporte de errores del DUT del área serie | Diego | Randy |
| Modelo de interrupciones completo (prioridades, *timeout*) | Randy | Eric |
| Aserciones de módem y *loopback* con `cover property` | Randy | Eric |
| Covergroups de módem e interrupciones | Randy | Eric |
| Reporte de errores del DUT del área de módem e interrupciones | Randy | Eric |
| Línea base (200 o más semillas) y curva de saturación | Eric (ejecuta), cada quien interpreta su dominio | Randy |
| Análisis de huecos, archivos `.args` y exclusiones `.el` | Cada dueño sobre su dominio | Su revisor |
| Informe de cierre consolidado | Randy | Eric y Diego |
| Informe final (cada quien su área) | Todos | En anillo |
| Presentación y demo en vivo (25 min) | Los tres presentan | n/a |

Cada hueco de cobertura lo clasifica en las categorías a, b, c o d (sección 6.2 del enunciado) el dueño del dominio, y lo valida su revisor.

---

## 6. Flujo de Git

### Ramas fijas

| Rama | Uso |
|---|---|
| `main` | Estable. Solo recibe merges desde `develop` al cerrar cada entrega, con las etiquetas `entrega1`, `entrega2` y `final` |
| `develop` | Integración. Debe compilar siempre |

### Ramas de trabajo (`área/descripción`)

| Persona | Ejemplos |
|---|---|
| Eric | `wb/agent`, `wb/driver-delays`, `wb/monitor`, `wb/cfg`, `ral/reg-block`, `ral/adapter-predictor`, `ral/backdoor`, `ral/builtin-seqs`, `sva/wishbone`, `scb/reg-mirror`, `cov/registers`, `tb/top`, `reg/regression-script` |
| Diego | `ser/agent`, `ser/driver-errors`, `ser/monitor-tx-rx`, `ser/cfg`, `ral/serial-regs`, `seq/ser-traffic`, `scb/tx-rx-data`, `scb/lsr-fifo`, `sva/serial`, `cov/line-traffic-errors` |
| Randy | `modem/agent`, `modem/cfg`, `irq/monitor`, `ral/modem-irq-regs`, `seq/modem-irq`, `scb/irq-model`, `scb/msr`, `sva/modem-loopback`, `cov/modem-irq`, `env/uart-env`, `test/base-test`, `vseq/main-sequence` |

Ramas compartidas: `docs/plan-e1`, `docs/informe-final`, `fix/<área>-<bug>`, `bug/dut-<id>`.

### Reglas

- Una rama por issue, de vida corta (idealmente menos de una semana), que sale de `develop` y vuelve a `develop` por PR.
- El PR referencia el issue (`Closes #N`) y asigna al revisor del anillo.
- Rebase sobre `develop` antes de pedir revisión.
- Cada integrante hace commits con su propia cuenta.
- No se versionan salidas de simulación (`simv`, `csrc`, `*.vdb`, `*.log`).
- No se modifica el RTL para que las pruebas pasen. Un error real se documenta en `bug/dut-<id>`.

### Etiquetas sugeridas para issues

`area:wb`, `area:ral`, `area:ser`, `area:modem`, `area:irq`, `area:env`, `area:cfg`, `area:cov`, `area:scb`, `area:sva`, `entrega:E1`, `entrega:E2`, `entrega:E3`, `tipo:bug-dut`, `tipo:docs`.

---

## 7. Prácticas para que todos aporten y todos entiendan

- **Sesión de traspaso:** antes de E2 y de E3, cada integrante explica su bloque a los otros dos (30 min).
- **Cambio en vivo:** una vez por entrega, cada revisor hace un cambio pequeño en el código de su revisado (un *knob* con su plusarg, un *bin* o una aserción). Es el ensayo de la entrevista individual.
- **RAL compartido:** Eric lleva la infraestructura, pero Diego y Randy escriben y entienden las clases de sus registros, de modo que el RAL no queda en una sola cabeza.
- **Balance:** al asignar issues se compara el esfuerzo estimado de cada uno, no solo la cantidad. Si la carga se desbalancea (por ejemplo, el modelo de FIFOs de Diego o el RAL de Eric), se redistribuye en la siguiente revisión del plan.
