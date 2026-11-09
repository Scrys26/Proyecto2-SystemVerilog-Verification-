# CLAUDE.md: Verificación UVM del UART 16550 (EL5811)

Proyecto de tres integrantes. DUT: `uart16550` de OpenCores, bus de 32 bits. Simulador: Synopsys VCS con UVM 1.2. Documentos de referencia en el repositorio: enunciado, plan de pruebas, `REGLAS_PLUSARGS_KNOBS.md` y `UART_spec.pdf`.

## 1. Contexto de trabajo

- Mi parte (Eric): interfaces, `tb_top`, reloj y reset, agente Wishbone y `wb_agent_cfg`, RAL (bloque, adaptador, predictor, `uvm_reg_hw_reset_seq`), aserciones SVA de Wishbone, script de regresión. Prefijos de plusargs: `WB`, `REG`, `RST`.
- Diego: agente serie y secuencias TX/RX, covergroups. Prefijos `SER`, `LCR`, `DL`, `FCR`, `TX`.
- Randy: agente de módem, monitor de interrupción, secuencia virtual, scoreboard, `parse_plusargs()`. Prefijos `MODEM`, `MCR`, `IER`, `INT`, `SW`, `CFG`.
- Los tres debemos poder explicar y modificar cualquier parte del código (entrevista individual eliminatoria). Todo lo que se escriba debe poder entenderse leyéndolo.
- Idioma: español. Términos del equipo: "randomizar" y "sesión de tráfico".

## 2. Cómo trabajamos Claude y yo

- **Escribo yo** el driver y monitor Wishbone, el adaptador, el predictor y las secuencias del RAL. Claude no los escribe completos salvo que lo pida explícitamente.
- **Claude genera** lo repetitivo: boilerplate de `uvm_object_utils` y `uvm_component_utils`, definición de campos del RAL, Makefile y scripts.
- **Claude revisa** todo lo que escribo: errores, violaciones de UVM, violaciones de las reglas de la sección 3, y por qué lo son.
- Cuando algo no sea trivial, explicar el porqué (qué falla si se quita, qué regla aplica). Si hay varias formas razonables de hacer algo, presentar las opciones con ventajas y costos, y dejar que yo decida.
- Antes de cualquier decisión de diseño, preguntar. No decidir en silencio.
- Antes de escribir código que dependa del comportamiento del DUT, leer el RTL en `rtl/verilog/` y citar el archivo y la línea. No suponer comportamiento.
- Un commit pequeño por paso, con mi cuenta. Mensajes en español, en imperativo.

## 3. Reglas del proyecto (no negociables)

Del enunciado (E1 a E12):
1. Una sola prueba, `uart_base_test`, más semillas y archivos `.args`. Prohibido crear pruebas dirigidas como clases nuevas.
2. Un único punto de lectura de plusargs: `parse_plusargs()` con `uvm_cmdline_processor`. Prohibido `$value$plusargs` en drivers, monitores o secuencias.
3. Todo valor leído va a un knob de un objeto de configuración y se publica con `uvm_config_db#(...)::set` en `build_phase`.
4. Los componentes obtienen su cfg con `::get` verificado (con `uvm_fatal` si falla). Las secuencias lo obtienen vía su secuenciador.
5. Las restricciones usan knobs, sin constantes mágicas.
6. Plusargs con nombre `+UART_<BLOQUE>_<KNOB>=<valor>`, en mayúsculas. Sufijos: `_WEIGHTS`, `_PCT`, `_MIN`, `_MAX`, `_EN`. Un plusarg es un knob.
7. Al inicio de cada simulación se imprime cada knob con su valor y origen (`default` o `plusarg`), con el tag `[KNOBS]`.
8. Con los valores por defecto, ningún escenario legal queda en probabilidad cero. Todo acotamiento tiene plusarg que lo amplía y justificación en el plan.
9. Todo componente y objeto se crea por la factory (`type_id::create`). Nunca `new` directo.
10. Cobertura muestreada desde monitores, RAL o scoreboard, nunca desde el driver.
11. Fin de prueba con objeciones, sin `#delay` arbitrarios.
12. **No modificar el RTL** para que las pruebas pasen. Un error real se documenta (escenario, semilla, plusargs, esperado, observado, recomendación).

Calidad: cero advertencias de compilación propias del ambiente. `UVM_ERROR` y `UVM_FATAL` en cero en una corrida que pasa.

## 4. Principios de diseño aplicados aquí

- **SRP.** Driver: solo maneja señales. Monitor: solo observa y publica. Scoreboard: solo compara. Cfg: solo knobs. `parse_plusargs()`: solo lee. Una secuencia hace una cosa; la virtual las combina.
- **SSOT.** El valor por defecto de un knob vive solo en su declaración. Direcciones, resets y campos de registros viven solo en el RAL. Las constantes globales (reloj, ancho de bus, profundidad de FIFO) viven en un paquete único. El modelo de referencia sale de la especificación y del análisis del RTL, nunca copiando la lógica del DUT.
- **DRY.** Un solo `csv_to_ints` en un paquete compartido. Una secuencia base con acceso a cfg y secuenciador. Un helper de acceso a registros por el RAL (incluye el protocolo DLAB). Si la repetición es más legible que la abstracción, se acepta y se explica.
- **SOLID.** O: extender por factory (`set_type_override`) o clases derivadas, sin editar clases que ya funcionan. L: un item o secuencia derivada se usa donde se espera la base. I: puertos de análisis separados por fuente (`wb_ap`, `tx_ap`, `rx_ap`, `modem_ap`, `int_ap`). D: los componentes dependen de cfg e interfaces virtuales recibidas por `config_db`, no de rutas jerárquicas al DUT.
- **TDD (ligero).** Aplica al RAL y al scoreboard: escribir primero la comprobación esperada (por ejemplo, `write LCR` y `read LCR`, o `uvm_reg_hw_reset_seq`) y después el componente. Para lo demás, una prueba de humo mínima antes de integrar. Probar al probador: inyectar un error a propósito para confirmar que el scoreboard lo detecta.
- Centralizar datos (constantes, knobs, registros); separar comportamiento (clases pequeñas).

## 5. Convenciones de código

- Un archivo por clase, con el nombre de la clase. Paquetes: `uart_cfg_pkg`, `wb_pkg`, `uart_ral_pkg`, etc.
- Componentes y objetos con su macro de factory. Nombres de instancia en minúsculas con guion bajo.
- Mensajes con `uvm_info` y tag consistente (`KNOBS`, `DRV`, `MON`, `SCB`, `RAL`, `CFG`). Verbosidad por defecto `UVM_LOW`.
- Cada knob nuevo sigue los 10 pasos de `REGLAS_PLUSARGS_KNOBS.md`, sección 3. Un prefijo nuevo se agrega ahí antes de usarlo.
- Cada aserción con su `cover property`.
- Comentarios solo donde expliquen el porqué, no el qué.

## 6. Flujo de corridas (VCS en servidor remoto)

Claude no tiene acceso al servidor. Los logs, `.vdb` y ondas **nunca** se suben a git.

Ciclo:
1. Escribo la comprobación esperada y hago `git push`.
2. En el servidor: `git pull` y `make smoke SEED=<n> TXN_MAX=5` (corrida corta; deja `results/smoke_<n>.md`).
3. `make publish NAME=smoke_<n>` sube `results/` a la rama `runs`.
4. En mi máquina: `git fetch origin runs && git checkout origin/runs -- results/`.
5. Claude lee `results/` y analiza: causa probable (ambiente, DUT o especificación) y siguiente paso.

Regresiones: `make regr_digest` genera `results/regr_summary.csv` (una línea por corrida). Se analiza el CSV y solo el resumen detallado de las corridas fallidas.

Herramientas: `scripts/digest.py` (resúmenes), `scripts/publish_runs.sh` (publicación con límite de 200 KB por archivo), `Makefile.runs`.

Al analizar un resumen, Claude debe:
- Confirmar semilla, `.args` y commit antes de interpretar nada.
- Revisar la traza `[KNOBS]` para entender qué se randomizó.
- Distinguir entre error del ambiente, discrepancia de la especificación y error del DUT.
- Si el resumen está incompleto (sin `UVM Report Summary`), tratarlo como cuelgue o abort, no como PASS.
- No proponer ajustes al ambiente o al RTL solo para que pase. Primero explicar la causa.

## 7. Cobertura y cierre

- Meta: al menos 95 % en cobertura funcional y en cada métrica de código (línea, condición, rama, FSM, toggle), medida sobre la regresión fusionada con `urg`, con `-cm_hier` limitado a `uart_top`.
- Línea base: solo `uart_base_test` con defaults y N ≥ 200 semillas.
- Cada hueco se clasifica en: (a) alcanzable de baja probabilidad, (b) falta capacidad de estímulo, (c) inalcanzable, (d) bloqueado por error del DUT.
- Exclusiones solo con archivo `.el` versionado y comentario de justificación por elemento.
- Prohibido: eliminar bins, usar `option.weight = 0` o `ignore_bins` para esconder huecos alcanzables, y excluir código alcanzable solo porque no se cubrió.

## 8. Puntos abiertos de la especificación (ver sección 3 del plan)

Documentados en el plan, a confirmar contra el RTL antes de modelar: registro scratch en la dirección 7, lectura de vuelta del MCR, polaridad de RTS, DTR y MSR[7:4], condición de TERI, decodificación con `wb_sel_i` no one-hot, comportamiento con 1.5 y 2 bits de parada. Si el código que se va a escribir depende de uno de estos puntos, leer el RTL y avisar antes de asumir.
