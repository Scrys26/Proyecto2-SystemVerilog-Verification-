# Reglas de knobs y plusargs

Proyecto UART 16550 con UVM (EL5811). **E1 a E12** vienen del enunciado y no cambian. Las **convenciones (sección 2)** son del equipo y se pueden cambiar si los tres acuerdan.

## 1. Conceptos

| Término | Qué es |
|---|---|
| Variable aleatoria | Campo `rand` que decide `randomize()` |
| Knob | Campo **no aleatorio** de un objeto de configuración que controla *cómo* se aleatoriza (pesos, rangos, probabilidades, habilitadores) |
| Plusarg | Argumento de línea de comando que cambia un knob sin recompilar |
| `.args` | Archivo de plusargs que define un caso de esquina (`-f`) |

Flujo: `plusarg → parse_plusargs() → knob en el cfg → uvm_config_db → restricción → randomize()`.
Un caso de esquina **no es una prueba nueva**: es `uart_base_test` con otros plusargs y otra semilla.

## 2. Reglas

### Del enunciado (obligatorias)

| # | Regla |
|---|---|
| E1 | Una sola prueba, `uart_base_test`, más semillas y `.args`. Sin pruebas dirigidas como clases nuevas. |
| E2 | **Un único punto de lectura** (`parse_plusargs()` con `uvm_cmdline_processor`). Ningún driver, monitor ni secuencia usa `$value$plusargs`. |
| E3 | Todo valor leído se guarda en un knob de un objeto de configuración (`uart_env_cfg`, `wb_agent_cfg`, `uart_ser_agent_cfg`, `modem_agent_cfg`, `uart_scb_cfg`, `uart_cov_cfg`) y se publica con `uvm_config_db#(...)::set` en `build_phase`. |
| E4 | Todos los componentes obtienen su cfg con `::get`. Las secuencias, vía su secuenciador (`get_sequencer()` o `p_sequencer`). |
| E5 | Las restricciones usan rangos o pesos de los knobs, sin constantes mágicas. |
| E6 | Nombre `+UART_<BLOQUE>_<KNOB>=<valor>`; tabla completa en el plan (sección 7 del machote). |
| E7 | Al inicio de cada simulación se imprime cada knob con su valor y origen (`default` o `plusarg`). |
| E8 | Con los valores por defecto, la prueba base alcanza cualquier configuración o tráfico legal con probabilidad mayor que cero. |
| E9 | Ningún valor por defecto lleva un escenario legal a probabilidad cero. Si se acota un rango (ej. DL de 1 a 16), la cola sigue alcanzable con probabilidad pequeña, existe un plusarg que la amplía y el acotamiento se justifica en el plan. |
| E10 | El reset aleatorio se controla con un plusarg (puede estar apagado por defecto, con justificación). |
| E11 | Todo componente y objeto se crea por la *factory*. |
| E12 | Los *bins* que solo se alcanzan con plusargs se listan en el informe de cierre. |

### Convenciones del equipo

**Nombre:** `+UART_<BLOQUE>_<KNOB>`, en mayúsculas. El campo en código usa el mismo nombre en minúsculas (`+UART_DL_TAIL_PCT` ↔ `dl_tail_pct`).

| Sufijo | Significa | Valor |
|---|---|---|
| `_WEIGHTS` | Pesos de un `dist`, en el orden de los códigos de la especificación | Lista con comas, sin espacios: `0,0,0,1` |
| `_PCT` | Probabilidad | Entero 0 a 100 |
| `_MIN` / `_MAX` | Límites de un rango | Entero sin signo |
| `_EN` | Habilita un comportamiento | `0` o `1` |

- Un plusarg = un knob. Sin duplicados.
- El valor por defecto se escribe en la **declaración** del campo. Excepción: un caso no legal (ej. `wb_sel_i` con varios bits activos) puede tener 0, anotado en la tabla del plan.
- **¿Es knob?** Sí, si algún caso de esquina necesita cambiarlo o si deja una cola de baja probabilidad. No, si es una constante del DUT (ej. FIFO de 16).

**Prefijos y dueños (propuesta, por confirmar):**

| Dueño | Prefijos | Cfg |
|---|---|---|
| Eric | `WB`, `REG`, `RST` | `wb_agent_cfg`, `uart_env_cfg` |
| Diego | `SER`, `LCR`, `DL`, `FCR`, `TX` | `uart_ser_agent_cfg` |
| Randy | `MODEM`, `MCR`, `IER`, `INT`, `SW`, `CFG` | `modem_agent_cfg`, `uart_scb_cfg`, `uart_env_cfg` |

Un prefijo nuevo se agrega aquí antes de usarlo.

## 3. Agregar un knob

1. Justificar el escenario o *bin* que lo necesita.
2. Elegir prefijo y nombre (sección 2); revisar que no exista uno equivalente.
3. Declararlo en el cfg del bloque, con su valor por defecto.
4. Usarlo en la restricción (E5).
5. Leerlo en `parse_plusargs()` y registrar su origen.
6. Validarlo en `check_knobs()` (rangos coherentes, al menos un peso > 0).
7. Verificar `::set` y `::get` (E3, E4).
8. Agregarlo a la tabla de plusargs del plan (sección 4 de este documento).
9. Referenciarlo en la matriz de verificación o en un caso de esquina.
10. Abrir el PR con el revisor del anillo y la lista de la sección 6.

## 4. Documentación y `.args`

**Tabla de plusargs (sección 7 del plan), columnas obligatorias:**

| Plusarg | Tipo y rango | Valor por defecto | Componentes que lo usan | Objeto de configuración | Efecto |
|---|---|---|---|---|---|
| `+UART_SER_PARITY_ERR_PCT` | Entero 0 a 100 | 5 | Driver serie, scoreboard | `uart_ser_agent_cfg` | % de caracteres RX con paridad corrupta |

Cada acotamiento por defecto además lleva su argumento de completitud en la sección 6.2 del plan.

**Archivos `.args`:** en `tests/`, nombre descriptivo (`rx_overrun_tl14_5bit.args`), solo plusargs (uno por línea), sin semilla. Cada uno se registra en la sección 8 del plan (ID, escenario, plusargs, *bins* objetivo, semillas).

```
./simv +UVM_TESTNAME=uart_base_test +ntb_random_seed=1234 -f tests/rx_overrun_tl14_5bit.args
```

## 5. Plantilla de código

> Orientativa, adaptada del enunciado (4.2). **No se ha compilado**: ajustar al compilar con VCS.

```systemverilog
class uart_line_cfg extends uvm_object;
  `uvm_object_utils(uart_line_cfg)

  rand bit [1:0]  wls;                       // variables aleatorias
  rand bit [15:0] dl;

  int unsigned wls_w[4]    = '{1,1,1,1};     // knobs: +UART_LCR_WLS_WEIGHTS
  int unsigned dl_min = 1, dl_max_fast = 16, // +UART_DL_MIN, _MAX_FAST
               dl_max = 16'hFFFF;            // +UART_DL_MAX
  int unsigned dl_tail_pct = 2;              // +UART_DL_TAIL_PCT

  string origin[string];                     // para la traza (E7)
  function string org(string k);
    return origin.exists(k) ? origin[k] : "default";
  endfunction

  constraint c_wls { wls dist { 0:=wls_w[0], 1:=wls_w[1], 2:=wls_w[2], 3:=wls_w[3] }; }
  constraint c_dl  { dl dist { [dl_min:dl_max_fast]   :/ (100 - dl_tail_pct),
                               [dl_max_fast+1:dl_max] :/ dl_tail_pct }; }

  function new(string name = "uart_line_cfg"); super.new(name); endfunction

  function void parse_plusargs();            // único punto de lectura (E2)
    uvm_cmdline_processor clp = uvm_cmdline_processor::get_inst();
    string v;
    if (clp.get_arg_value("+UART_DL_MAX=", v)) begin
      dl_max = v.atoi(); origin["dl_max"] = "plusarg";
    end
    if (clp.get_arg_value("+UART_LCR_WLS_WEIGHTS=", v)) begin
      int unsigned q[$];
      csv_to_ints(v, q);                     // helper común, abajo
      if (q.size() != 4) `uvm_fatal("CFG", "LCR_WLS_WEIGHTS requiere 4 pesos")
      foreach (q[i]) wls_w[i] = q[i];
      origin["wls_w"] = "plusarg";
    end
    // ... un bloque por knob
    check_knobs();
  endfunction

  function void check_knobs();
    if (wls_w.sum() == 0)                      `uvm_fatal("CFG", "Pesos de WLS en 0")
    if (dl_min > dl_max_fast || dl_max_fast >= dl_max)
                                               `uvm_fatal("CFG", "Rangos de DL incoherentes")
    if (dl_tail_pct > 100)                     `uvm_fatal("CFG", "DL_TAIL_PCT fuera de 0..100")
  endfunction

  function void report_knobs();              // traza (E7)
    `uvm_info("KNOBS", $sformatf("lcr.wls_w = %p (%s)", wls_w, org("wls_w")), UVM_LOW)
    `uvm_info("KNOBS", $sformatf("dl.max    = %0d (%s)", dl_max, org("dl_max")), UVM_LOW)
  endfunction
endclass

// "0,0,0,1" -> '{0,0,0,1}   (paquete compartido uart_cfg_utils)
function automatic void csv_to_ints(string s, ref int unsigned q[$]);
  int start = 0;
  q.delete();
  for (int i = 0; i <= s.len(); i++)
    if (i == s.len() || s[i] == ",") begin
      q.push_back(s.substr(start, i-1).atoi());
      start = i + 1;
    end
endfunction
```

Publicación y uso:

```systemverilog
// uart_base_test::build_phase
line_cfg = uart_line_cfg::type_id::create("line_cfg");
line_cfg.parse_plusargs();
uvm_config_db#(uart_line_cfg)::set(this, "env.*", "line_cfg", line_cfg);

// cualquier componente
if (!uvm_config_db#(uart_line_cfg)::get(this, "", "line_cfg", cfg))
  `uvm_fatal("CFG", "No se encontró line_cfg")
```

**Plusargs mal escritos:** un error de tipeo se ignora en silencio. `uart_base_test` compara los `+UART_*` de la línea de comando (`get_args`) contra los nombres registrados y emite `uvm_error` por cada desconocido.

## 6. Lista de verificación del PR

- [ ] Nadie fuera de `parse_plusargs()` lee la línea de comando (E2).
- [ ] El knob vive en un cfg, se publica con `::set` y se obtiene con `::get` verificado (E3, E4).
- [ ] La restricción usa el knob, sin constantes (E5); el valor por defecto está en la declaración.
- [ ] `check_knobs()` valida rango y pesos; el knob se imprime con su origen (E7).
- [ ] Nombre `+UART_<BLOQUE>_<KNOB>` en mayúsculas, sufijo correcto, prefijo existente y del dueño correcto.
- [ ] Con los defaults no queda ningún caso legal en probabilidad cero; todo acotamiento tiene plusarg que lo amplía y justificación (E8, E9).
- [ ] Está en la tabla de plusargs del plan y referenciado en la matriz o en un caso de esquina; el `.args` (si hay) está en la sección 8.
- [ ] Componentes creados por la *factory* (E11).

## 7. Errores comunes

| Error | Solución |
|---|---|
| `$value$plusargs` en un driver, monitor o secuencia | Solo `parse_plusargs()`; el componente usa el knob |
| Constante en la restricción (`dl inside {[1:16]}`) | Mover el límite a un knob |
| Default que deja un caso legal en 0 | Cola con `_TAIL_PCT` y plusarg que la amplíe |
| Plusarg con error de tipeo | Detección de `+UART_*` desconocidos |
| Dos plusargs para lo mismo | Un plusarg por knob |
| Pesos en distinto orden al documentado | Orden de la especificación, documentado en la tabla |
| Espacios en el valor (`0, 0, 0, 1`) | Comas sin espacios |
| Prueba dirigida como clase nueva | Un `.args` sobre `uart_base_test` |
| Plusarg creado solo para esconder un hueco de cobertura | Un plusarg se justifica por el escenario que ejerce