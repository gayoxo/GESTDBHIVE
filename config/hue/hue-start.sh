#!/bin/sh
# Arranque de Hue: igual que el startup.sh de la imagen (migrate + supervisor),
# pero crea o actualiza antes el administrador HUE_ADMIN_USER / HUE_ADMIN_PASSWORD.
set -e
cd /usr/share/hue

./build/env/bin/hue migrate

./build/env/bin/hue shell -c "
import os
from django.contrib.auth.models import User
usuario, creado = User.objects.get_or_create(username=os.environ['HUE_ADMIN_USER'])
usuario.is_superuser = True
usuario.is_staff = True
usuario.is_active = True
usuario.set_password(os.environ['HUE_ADMIN_PASSWORD'])
usuario.save()
print('Administrador de Hue', 'creado:' if creado else 'actualizado:', usuario.username)
"

exec ./build/env/bin/supervisor
