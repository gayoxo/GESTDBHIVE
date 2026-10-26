# Funciones comunes de los scripts. Se carga con: source scripts/_comun.sh

# Comprueba que se ejecuta en un bash con acceso a Docker. En Windows, el
# comando "bash" de PowerShell suele ser el de WSL (C:\Windows\System32\bash.exe),
# que normalmente no tiene Docker: hay que usar Git Bash.
comprobar_entorno() {
  docker info >/dev/null 2>&1 && return 0

  if grep -qi microsoft /proc/version 2>/dev/null; then
    echo 'ERROR: se esta ejecutando el bash de WSL (Linux), no Git Bash, y desde aqui no hay Docker.'
    echo '  Ocurre al escribir "bash scripts/..." en PowerShell: ese "bash" es WSL.'
    echo '  Soluciones (cualquiera de ellas):'
    echo '   - VS Code: Terminal > Nuevo terminal (este proyecto abre Git Bash por defecto).'
    echo '   - PowerShell: & "C:\Program Files\Git\bin\bash.exe" scripts/preflight.sh'
    echo '   - Seguir en WSL: Docker Desktop > Settings > Resources > WSL integration,'
    echo '     activar la distribucion (p. ej. Ubuntu) y abrir el proyecto desde ella.'
  elif ! command -v docker >/dev/null 2>&1; then
    echo 'ERROR: no se encuentra el comando "docker". Instalar Docker Desktop.'
  else
    echo 'ERROR: Docker no responde. Arrancar Docker Desktop y esperar a que indique "Engine running".'
  fi
  exit 1
}
