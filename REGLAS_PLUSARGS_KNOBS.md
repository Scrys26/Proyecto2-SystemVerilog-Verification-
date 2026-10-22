# Reglas para crear knobs y plusargs

Proyecto: verificación del UART 16550 con UVM (EL5811).

Este documento es la referencia del equipo para crear, nombrar, documentar y revisar **knobs** y **plusargs**. Tiene dos tipos de reglas:

- **Reglas del enunciado:** vienen de las secciones 4.1, 4.2, 5.3 y 6 del enunciado (`enunciado_proyecto_uart16550.md`). No se negocian.
- **Convenciones del equipo:** las definimos nosotros para trabajar de forma consistente. Se pueden cambiar si los tres están de acuerdo y se anota aquí.

Cada regla indica cuál de los dos tipos es.

---

## 1. Vocabulario

| Término | Qué es | Ejemplo |
|---|---|---|
| **Variable aleatoria** | Campo `rand` que decide `randomize()` en cada corrida | `rand bit [1:0] wls;` |
| **Knob** | Campo **no aleatorio** de un objeto de configuración que controla *cómo* se aleatoriza (pesos, rangos, probabilidades, habilitadores) | `int unsigned wls_w[4] = '{1,1,1,1};` |
| **Plusarg** | Argumento de la línea de comando que cambia el valor de un knob sin recompilar | `+UART_LCR_WLS_WEIGHTS=0,0,0,1` |
| **Objeto de configuración** | Clase `uvm_object` que agrupa los knobs de un bloque y se publica en `uvm_config_db` | `uart_ser_agent_cfg` |
| **Archivo `.args`** | Archivo con un conjunto de plusargs que define un caso de esquina; se pasa con `-f` | `tests/rx_overrun_tl14_5bit.args` |

La cadena completa es:

```
plusarg en la línea de comando (o en un .args)
   → parse_plusargs() lo lee (único punto de lectura)
   → se guarda en un knob del objeto de configuración
   → uvm_config_db::set lo publica a todos los componentes
   → la restricción usa el knob (dist, rangos)
   → randomize() genera el estímulo
```

Un caso de esquina **no es una prueba nueva**: es la misma `uart_base_test` con otro conjunto de plusargs y una semilla.

---

## 2. Reglas del enunciado (obligatorias)

| # | Regla | Fuente |
|---|---|---|
| E1 | Toda la regresión usa **una sola prueba**, `uart_base_test`, más semillas y archivos de plusargs. No se aceptan pruebas dirigidas escritas como clases nuevas con estímulo propio. | 4 |
| E2 | **Un único punto de lectura.** Los plusargs se leen en un solo lugar (por ejemplo un método `parse_plusargs()` en la clase de configuración, usando `uvm_cmdline_processor`). Ningún driver, monitor ni secuencia llama a `$value$plusargs` directamente. | 4.2, regla 1 |
| E3 | **Todo pasa por objetos de configuración.** Cada valor leído se guarda en un knob de un objeto de configuración (`uart_env_cfg`, `wb_agent_cfg`, `uart_ser_agent_cfg`, `modem_agent_cfg`, `uart_scb_cfg`, `uart_cov_cfg`, etc.) y esos objetos se publican con `uvm_config_db#(...)::set` durante `build_phase`. | 4.2, regla 2 |
| E4 | **Disponibles en todos los componentes.** Agentes, drivers, monitores, secuenciadores, secuencias, scoreboard, predictor y colectores de cobertura obtienen su objeto con `uvm_config_db#(...)::get` y usan sus knobs. Las secuencias lo obtienen a través de su secuenciador (`get_sequencer()` o `p_sequencer`). | 4.2, regla 3 |
| E5 | **Restricciones parametrizadas por knobs.** Cada restricción usa rangos o pesos tomados de los knobs, no constantes mágicas. Los valores por defecto cumplen el requisito de completitud. | 4.2, regla 4 |
| E6 | **Convención de nombres** `+UART_<BLOQUE>_<KNOB>=<valor>`, por ejemplo `+UART_LCR_WLS_WEIGHTS=0,0,0,1` o `+UART_SER_PARITY_ERR_PCT=30`. El plan debe incluir la tabla completa de plusargs. | 4.2, regla 5 |
| E7 | **Trazabilidad.** Al inicio de cada simulación el ambiente imprime todos los knobs con su valor y su origen (por defecto o plusarg), para poder reproducir cualquier corrida con la semilla y el archivo de argumentos. | 4.2, regla 6 |
| E8 | **Completitud.** Con los valores por defecto, la prueba base debe poder generar cualquier configuración legal del DUT y cualquier tipo de tráfico que soporte: la probabilidad de alcanzar cada *bin* alcanzable con una semilla al azar debe ser mayor que cero. | 4.1 |
| E9 | **Ninguna restricción por defecto puede llevar la probabilidad de un escenario legal a cero.** Si por tiempo de simulación hay que acotar un rango (por ejemplo DL entre 1 y 16 por defecto), la cola completa del rango debe seguir siendo alcanzable con una probabilidad pequeña, y debe existir un plusarg que la amplíe. Cada acotamiento se justifica en el plan. | 4.1 |
| E10 | El **reset aleatorio** se controla con un plusarg (puede estar deshabilitado por defecto si se justifica). | 4.1 |
| E11 | Uso de la **factory** para todos los componentes y objetos, de modo que `+uvm_set_type_override` permita sustituir cualquier pieza. | 5.3 |
| E12 | Los *bins* que **solo se alcanzan con plusargs** se listan en el informe de cierre: son un indicador de restricciones por defecto demasiado estrechas. | 6.2 |

---

## 3. Convenciones del equipo

### 3.1 Estructura del nombre

```
+UART_<BLOQUE>_<KNOB>=<valor>
```

- Todo en **mayúsculas**, con guion bajo como separador.
- `<BLOQUE>` es el registro, agente o componente al que pertenece el parámetro.
- `<KNOB>` es el nombre del campo, con un sufijo que indica el tipo de valor (sección 3.2).
- El campo en el código usa el mismo nombre en **minúsculas**: `+UART_DL_TAIL_PCT` ↔ `dl_tail_pct`. Así se encuentra con un solo `grep`.

### 3.2 Sufijos por tipo de valor

| Sufijo | Significa | Formato del valor | Ejemplo |
|---|---|---|---|
| `_WEIGHTS` | Pesos de una distribución `dist`, uno por opción y en el orden de la especificación | Lista separada por comas, sin espacios | `+UART_FCR_TL_WEIGHTS=0,0,0,1` |
| `_PCT` | Probabilidad en porcentaje | Entero de 0 a 100 | `+UART_SER_BREAK_PCT=30` |
| `_MIN` / `_MAX` | Límites inferior y superior de un rango | Entero sin signo | `+UART_SW_SERVICE_DELAY_MIN=500` |
| `_EN` | Habilita o deshabilita un comportamiento | `0` o `1` | `+UART_RST_EN=1` |
| *(sin sufijo)* | Valor entero puntual | Entero | `+UART_WB_BUS_WIDTH=8` |

Reglas del formato:

- **Sin espacios** dentro del valor. Para listas se usa coma.
- Los pesos se escriben en el **orden de los códigos de la especificación** (por ejemplo `FCR_TL_WEIGHTS` va en el orden 1, 4, 8, 14 bytes; `LCR_WLS_WEIGHTS` en el orden 5, 6, 7, 8 bits). El orden se documenta en la tabla de la sección 7 del plan.
- Un plusarg tiene **un solo knob** y un knob tiene **un solo plusarg**.

### 3.3 Prefijos y dueños (propuesta, por confirmar)

El dueño del prefijo escribe y mantiene los knobs de su bloque, y el objeto de configuración donde viven. Es el reparto de `RESPONSABILIDADES.md` aplicado a los prefijos.

| Prefijo | Qué controla | Objeto de configuración | Dueño |
|---|---|---|---|
| `WB` | Agente Wishbone: retardos, `wb_sel_i`, ancho de bus | `wb_agent_cfg` | Eric |
| `REG` | Secuencias de registros: pesos por dirección, DLAB, accesos | `wb_agent_cfg` o cfg de secuencias | Eric |
| `RST` | Reset aleatorio | `uart_env_cfg` | Eric |
| `SER` | Agente serie: errores inyectados, ráfagas, baudios | `uart_ser_agent_cfg` | Diego |
| `LCR` | Configuración de línea: longitud, paridad, parada, break | `uart_ser_agent_cfg` (o cfg de línea) | Diego |
| `DL` | Divisor: rango, cola, orden de escritura | `uart_ser_agent_cfg` (o cfg de línea) | Diego |
| `FCR` | FIFO: nivel de disparo, limpieza | `uart_ser_agent_cfg` (o cfg de línea) | Diego |
| `TX` | Tráfico de transmisión: ráfagas, desborde | `uart_ser_agent_cfg` | Diego |
| `MODEM` | Agente de módem: cambios de entradas | `modem_agent_cfg` | Randy |
| `MCR` | Salidas de módem y *loopback* | `modem_agent_cfg` | Randy |
| `IER` | Habilitación de interrupciones | `uart_env_cfg` | Randy |
| `INT` | Monitor y modelo de interrupciones | `uart_scb_cfg` | Randy |
| `SW` | Estilo de servicio del software: sondeo o interrupciones, retardos | `uart_env_cfg` | Randy |
| `CFG` | Reconfiguración durante el tráfico y secuencia principal | `uart_env_cfg` | Randy |

Un prefijo nuevo se agrega a esta tabla **antes** de usarlo en código.

### 3.4 Valores por defecto

- El valor por defecto de un knob se escribe **en la declaración** del campo, no en `parse_plusargs()`.
- Todo valor por defecto debe cumplir E8 y E9. Si un valor deja un caso legal en probabilidad cero, no es válido.
- Excepción documentada: un comportamiento **no legal o de riesgo** (por ejemplo `wb_sel_i` con más de un bit activo, que la especificación no define) puede tener 0 por defecto. Se anota en la tabla de plusargs que es un caso fuera de lo legal.
- Un plusarg que **amplía** un acotamiento por defecto (E9) se llama con `_MAX` o `_TAIL_PCT` y se documenta junto al acotamiento.

### 3.5 Una restricción, un knob

Antes de escribir una restricción, pregunten:

1. **¿Algún caso de esquina necesita cambiar este valor?** Si sí, es knob.
2. **¿El valor por defecto deja alguna cola alcanzable solo con probabilidad pequeña?** Entonces necesita knob para el rango y otro para la probabilidad de la cola.
3. **¿Es una constante del DUT?** Entonces no es knob. Por ejemplo, la profundidad de 16 de la FIFO es una constante del modelo, no un parámetro de estímulo.

---

## 4. Cómo agregar un knob nuevo (paso a paso)

1. **Justificar** en una frase qué escenario o *bin* necesita ese knob. Si no hay ninguno, no se crea.
2. **Elegir el prefijo y el nombre** según 3.1 a 3.3. Revisar que no exista ya uno equivalente.
3. **Declarar el campo** en el objeto de configuración del bloque, con su valor por defecto (3.4).
4. **Usarlo en la restricción** (E5): rangos o pesos tomados del knob, sin constantes.
5. **Leerlo en `parse_plusargs()`** de esa clase (E2). Registrar su origen (sección 6).
6. **Validar el valor** en `check_knobs()`: rangos coherentes y al menos un peso mayor que cero.
7. **Confirmar que el objeto se publica** con `::set` y que los componentes que lo necesitan lo obtienen con `::get` (E3 y E4).
8. **Agregarlo a la tabla de plusargs** del plan (sección 7), con todas las columnas (sección 7 de este documento).
9. **Referenciarlo** en la matriz de verificación (sección 5) si ejercita una característica, o en un caso de esquina (sección 8).
10. **Abrir el PR** con el revisor del anillo y la lista de verificación de la sección 9.

---

## 5. Plantilla de código

> Ejemplo orientativo para fijar el patrón. Está adaptado del ejemplo del enunciado (sección 4.2) y **no se ha compilado**: ajusten tipos y nombres al compilar con VCS.

```systemverilog
class uart_line_cfg extends uvm_object;
  `uvm_object_utils(uart_line_cfg)

  // --- variables aleatorias ---
  rand bit [1:0]  wls;
  rand bit [15:0] dl;

  // --- knobs (no aleatorios), con sus valores por defecto ---
  int unsigned wls_w[4]     = '{1,1,1,1};   // +UART_LCR_WLS_WEIGHTS
  int unsigned dl_min       = 1;            // +UART_DL_MIN
  int unsigned dl_max_fast  = 16;           // +UART_DL_MAX_FAST
  int unsigned dl_max       = 16'hFFFF;     // +UART_DL_MAX
  int unsigned dl_tail_pct  = 2;            // +UART_DL_TAIL_PCT

  // origen de cada knob, para la traza (E7); lo que no está aquí es "default"
  string origin[string];
  function string org(string k);
    return origin.exists(k) ? origin[k] : "default";
  endfunction

  // --- restricciones parametrizadas por knobs (E5) ---
  constraint c_wls {
    wls dist { 0 := wls_w[0], 1 := wls_w[1],
               2 := wls_w[2], 3 := wls_w[3] };
  }
  constraint c_dl {
    dl dist { [dl_min:dl_max_fast]    :/ (100 - dl_tail_pct),
              [dl_max_fast+1:dl_max]  :/ dl_tail_pct };
  }

  function new(string name = "uart_line_cfg");
    super.new(name);
  endfunction

  // Única función que lee la línea de comando (E2)
  function void parse_plusargs();
    uvm_cmdline_processor clp = uvm_cmdline_processor::get_inst();
    string v;
    if (clp.get_arg_value("+UART_DL_MAX=", v)) begin
      dl_max = v.atoi();           origin["dl_max"] = "plusarg";
    end
    if (clp.get_arg_value("+UART_DL_TAIL_PCT=", v)) begin
      dl_tail_pct = v.atoi();      origin["dl_tail_pct"] = "plusarg";
    end
    if (clp.get_arg_value("+UART_LCR_WLS_WEIGHTS=", v)) begin
      int unsigned q[$];
      csv_to_ints(v, q);
      if (q.size() != 4)
        `uvm_fatal("CFG", "+UART_LCR_WLS_WEIGHTS requiere 4 pesos: w5,w6,w7,w8")
      foreach (q[i]) wls_w[i] = q[i];
      origin["wls_w"] = "plusarg";
    end
    // ... un bloque por cada knob
    check_knobs();
  endfunction

  // Validación de coherencia
  function void check_knobs();
    if (wls_w[0] + wls_w[1] + wls_w[2] + wls_w[3] == 0)
      `uvm_fatal("CFG", "Todos los pesos de LCR_WLS son 0")
    if (dl_min > dl_max_fast || dl_max_fast >= dl_max)
      `uvm_fatal("CFG", "Rangos de DL incoherentes (min <= max_fast < max)")
    if (dl_tail_pct > 100)
      `uvm_fatal("CFG", "DL_TAIL_PCT fuera de 0..100")
  endfunction

  // Traza al inicio de la simulación (E7)
  function void report_knobs();
    `uvm_info("KNOBS", $sformatf("lcr.wls_w = %p  (%s)", wls_w, org("wls_w")), UVM_LOW)
    `uvm_info("KNOBS", $sformatf("dl.max      = %0d (%s)", dl_max, org("dl_max")), UVM_LOW)
    // ...
  endfunction
endclass
```

Helper común para listas (va en un paquete compartido, por ejemplo `uart_cfg_utils.sv`):

```systemverilog
// "0,0,0,1" -> '{0,0,0,1}
function automatic void csv_to_ints(string s, ref int unsigned q[$]);
  int start = 0;
  q.delete();
  for (int i = 0; i <= s.len(); i++) begin
    if (i == s.len() || s[i] == ",") begin
      q.push_back(s.substr(start, i-1).atoi());
      start = i + 1;
    end
  end
endfunction
```

Publicación y uso (E3 y E4):

```systemverilog
// En uart_base_test::build_phase
line_cfg = uart_line_cfg::type_id::create("line_cfg");
line_cfg.parse_plusargs();
uvm_config_db#(uart_line_cfg)::set(this, "env.*", "line_cfg", line_cfg);

// En cualquier componente
if (!uvm_config_db#(uart_line_cfg)::get(this, "", "line_cfg", cfg))
  `uvm_fatal("CFG", "No se encontró line_cfg")

// En una secuencia
cfg = p_sequencer.cfg;   // o get_sequencer() con cast
```

### Detección de plusargs mal escritos

Un plusarg con un error de tipeo se ignora en silencio y la corrida parece válida. Por eso `uart_base_test` revisa los argumentos `+UART_*` contra la lista de nombres registrados y avisa de los desconocidos:

```systemverilog
// En uart_base_test (antes de parse_plusargs)
string args[$];
uvm_cmdline_processor::get_inst().get_args(args);
foreach (args[i])
  if (args[i].substr(0, 5) == "+UART_" && !known_plusargs.exists(plusarg_name(args[i])))
    `uvm_error("CFG", $sformatf("Plusarg desconocido: %s", args[i]))
```

`known_plusargs` se llena a partir de los knobs registrados en cada objeto de configuración. `plusarg_name()` es un helper que corta el texto antes del `=`.

---

## 6. Trazabilidad y reproducción

Cada corrida debe poder reproducirse con **la semilla y el archivo `.args`**, y nada más.

- Al inicio de la simulación se imprime **cada knob con su valor y su origen** (`default` o `plusarg`), en un bloque con el tag `KNOBS`.
- La semilla se pasa con `+ntb_random_seed=<n>` y también se imprime.
- Los reportes de errores del DUT (sección 3.5 del enunciado) incluyen: escenario, semilla y plusargs para reproducirlo.

Ejemplo de la traza esperada (formato orientativo):

```
UVM_INFO @ 0: [KNOBS] lcr.wls_w          = '{0,0,0,1}  (plusarg)
UVM_INFO @ 0: [KNOBS] dl.max             = 65535       (default)
UVM_INFO @ 0: [KNOBS] dl.tail_pct        = 2           (default)
UVM_INFO @ 0: [KNOBS] ser.parity_err_pct = 30          (plusarg)
UVM_INFO @ 0: [KNOBS] seed               = 1234
```

---

## 7. Documentación obligatoria de cada plusarg

Cada plusarg se documenta en la **tabla de plusargs del plan** (sección 7 del machote), con estas columnas:

| Plusarg | Tipo y rango | Valor por defecto | Componentes que lo usan | Objeto de configuración | Efecto |
|---|---|---|---|---|---|
| `+UART_SER_PARITY_ERR_PCT` | Entero 0 a 100 | 5 | Driver serie, scoreboard | `uart_ser_agent_cfg` | Porcentaje de caracteres RX con paridad corrupta |

Para los acotamientos por defecto (E9), la sección 6.2 del plan agrega el argumento de completitud: por qué la probabilidad del escenario sigue siendo mayor que cero y qué plusarg lo acelera.

Las columnas deben estar completas antes de cerrar la entrega E1.

---

## 8. Archivos `.args` (casos de esquina)

- Se guardan en `tests/`.
- **Nombre descriptivo** del escenario: `rx_overrun_tl14_5bit.args`, `break_con_paridad_stick.args`.
- Un archivo contiene **solo plusargs**, uno por línea. La semilla se pasa aparte en la línea de comando.
- Cada archivo se registra en la sección 8 del plan (casos de esquina) con: ID, escenario, plusargs, *bins* objetivo y número de semillas.

Ejemplo del enunciado (sección 4.2):

```
./simv +UVM_TESTNAME=uart_base_test +ntb_random_seed=1234 \
       -f tests/rx_overrun_tl14_5bit.args
```

Contenido ilustrativo de `tests/rx_overrun_tl14_5bit.args` (los valores concretos se calibran en la práctica):

```
+UART_FCR_TL_WEIGHTS=0,0,0,1
+UART_LCR_WLS_WEIGHTS=1,0,0,0
+UART_SW_SERVICE_DELAY_MIN=2000
```

Para cada *bin* alcanzable solo con plusargs, el informe de cierre lo anota (E12).

---

## 9. Lista de verificación para el PR

El revisor del anillo confirma cada punto antes de aprobar un PR que agrega o modifica knobs o plusargs.

**Código**

- [ ] Ningún componente fuera de `parse_plusargs()` llama a `$value$plusargs` ni a `get_arg_value` (E2).
- [ ] Cada knob vive en un objeto de configuración y se publica con `::set` en `build_phase` (E3).
- [ ] Los componentes obtienen la configuración con `::get` y verifican el resultado (E4).
- [ ] Las restricciones usan knobs, sin constantes mágicas (E5).
- [ ] El valor por defecto está en la declaración del campo.
- [ ] `check_knobs()` valida el rango y que haya al menos un peso mayor que cero.
- [ ] El knob se imprime en la traza con su origen (E7).
- [ ] Los componentes se crean por la factory (E11).

**Nombres**

- [ ] El plusarg sigue `+UART_<BLOQUE>_<KNOB>` en mayúsculas.
- [ ] El sufijo corresponde al tipo de valor (3.2).
- [ ] El prefijo existe en la tabla 3.3 y pertenece al dueño correcto.
- [ ] El campo en el código tiene el mismo nombre en minúsculas.

**Completitud**

- [ ] Con los valores por defecto, no queda ningún caso legal con probabilidad cero (E8, E9).
- [ ] Si hay un acotamiento por defecto, existe un plusarg que lo amplía y está justificado en el plan.

**Documentación**

- [ ] El plusarg está en la tabla de la sección 7 del plan, con todas las columnas.
- [ ] Está referenciado en la matriz de verificación o en un caso de esquina.
- [ ] Si tiene un `.args` asociado, está registrado en la sección 8 del plan.

---

## 10. Errores comunes

| Error | Por qué es un problema | Cómo evitarlo |
|---|---|---|
| Leer `$value$plusargs` dentro de un driver, monitor o secuencia | Rompe E2 y dispersa la lectura | Solo `parse_plusargs()`; el componente usa el knob |
| Constante escrita en la restricción (`dl inside {[1:16]}`) | No se puede cambiar por plusarg y rompe E5 | Mover el límite a un knob |
| Valor por defecto que deja un escenario legal en 0 | Rompe la completitud (E8, E9) | Dejar una cola con `_TAIL_PCT` y un plusarg que la amplíe |
| Plusarg mal escrito que se ignora | La corrida parece válida pero no ejerció el caso | Detección de `+UART_*` desconocidos (sección 5) |
| Dos plusargs que controlan lo mismo | Confusión y resultados difíciles de reproducir | Un plusarg por knob; fusionar duplicados |
| Pesos en orden distinto al documentado | El caso de esquina apunta a otro valor | Orden de la especificación, documentado en la tabla |
| Valores con espacios (`0, 0, 0, 1`) | La línea de comando los parte en argumentos | Coma sin espacios |
| Prueba dirigida como clase nueva | No se acepta (E1) | Un `.args` sobre `uart_base_test` |
| Knob sin entrada en la tabla del plan | El informe y la entrevista no lo pueden explicar | Documentarlo antes de abrir el PR |
| Plusarg que solo existe para esconder un hueco | Equivale a excluir cobertura alcanzable (sección 6.3 del enunciado) | Un plusarg se justifica por el escenario que ejerce |

---

## 11. Estado de este documento

- Las **reglas E1 a E12** son del enunciado y no cambian.
- Las **convenciones de la sección 3** (sufijos, prefijos y dueños, formato de valores) son propuestas del equipo; los dueños de prefijos están pendientes de confirmar.
- Los **51 plusargs** que aparecen en la matriz de verificación (sección 5 del plan) son nombres propuestos. Los definitivos se fijan al consolidar la tabla de la sección 7.
- Los fragmentos de código son orientativos y no se han compilado.
