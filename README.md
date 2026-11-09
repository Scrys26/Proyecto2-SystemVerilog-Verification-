# UART 16550: verificacion con SystemVerilog y UVM

Base de verificacion funcional del UART 16550 con Synopsys VCS y UVM 1.2.
El RTL en `rtl/verilog/` es el DUT de referencia y no debe modificarse.

## Compilar y ejecutar

Desde la raiz del repositorio, con VCS/UVM disponibles en el entorno:

```sh
make                  # compila y ejecuta uart_hello_test con semilla 1
make run SEED=42      # ejecuta otra semilla
make BUS8=1           # compila para bus de 8 bits
make cov              # genera el reporte de cobertura
make smoke SEED=42    # corrida corta y resumen en results/
```

Los artefactos de simulacion se guardan en la raiz o en `work/` y estan
ignorados por Git. Los resumenes de `results/` se publican en la rama `runs`
con `make publish NAME=<corrida>`.

## Estructura actual

| Ruta | Contenido |
|---|---|
| `rtl/verilog/` | RTL del DUT. |
| `tb/` | `tb_top.sv`, lista de compilacion y `interfaces/`. |
| `sva/` | Modulo de aserciones y enlace `bind`. |
| `test/` | Prueba de humo UVM existente. |
| `docs/` | Especificacion, enunciado, plan, reglas y tutorial. |
| `scripts/` | Resumen de corridas y publicacion en la rama `runs`. |
| `Makefile` / `Makefile.runs` | Compilacion, simulacion, cobertura y corridas. |
| `.vscode/` | Asociacion de archivos SystemVerilog/Verilog para VS Code. |

El ambiente UVM completo (agentes, RAL, scoreboard, cobertura y secuencias)
aun debe construirse; no se incluyen modulos vacios para esos componentes.

Para mas contexto, consulta [el tutorial](docs/TUTORIAL.md), [el enunciado](docs/enunciado_proyecto.md) y [el plan de pruebas](docs/plan_de_pruebas.md).

Origen del RTL: [uart16550 de OpenCores](https://opencores.org/projects/uart16550),
espejo [freecores/uart16550](https://github.com/freecores/uart16550), commit
`2b0ad80`. Licencia GNU LGPL (ver el encabezado de cada archivo de
`rtl/verilog/`).
