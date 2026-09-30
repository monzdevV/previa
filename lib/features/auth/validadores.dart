/// Validaciones de formulario compartidas entre entrar y registro.
///
/// Antes bastaba con que el correo tuviera una "@"; eso deja pasar "a@" o
/// "@b" y el error solo aparece tras ir a la red. Esta comprobación es
/// deliberadamente simple (la validación de verdad la hace el servidor):
/// algo, una arroba, un dominio con al menos un punto y sin espacios.
final _patronCorreo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

bool esCorreoValido(String? valor) =>
    valor != null && _patronCorreo.hasMatch(valor.trim());
