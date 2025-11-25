# Script para eliminar todas las tareas de la aplicación
# Usa la API para listar y eliminar todas las tareas

param(
    [string]$Target = "http://localhost"
)

$ErrorActionPreference = "Stop"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "       LIMPIEZA DE TAREAS" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target: $Target/api/tasks" -ForegroundColor White
Write-Host ""

try {
    # Obtener todas las tareas
    Write-Host "[1/2] Obteniendo lista de tareas..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$Target/api/tasks" -Method GET -UseBasicParsing

    if ($response.Count -eq 0) {
        Write-Host ""
        Write-Host "No hay tareas para eliminar." -ForegroundColor Green
        Write-Host ""
        exit 0
    }

    Write-Host "      Tareas encontradas: $($response.Count)" -ForegroundColor White
    Write-Host ""

    # Eliminar cada tarea
    Write-Host "[2/2] Eliminando tareas..." -ForegroundColor Yellow
    $deleted = 0
    $failed = 0

    foreach ($task in $response) {
        try {
            $null = Invoke-RestMethod -Uri "$Target/api/tasks/$($task.id)" -Method DELETE -UseBasicParsing
            $deleted++
            Write-Host "      [$deleted/$($response.Count)] Eliminada: $($task.text.Substring(0, [Math]::Min(50, $task.text.Length)))..." -ForegroundColor Gray
        }
        catch {
            $failed++
            Write-Host "      ERROR al eliminar tarea $($task.id): $_" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "       LIMPIEZA COMPLETADA" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Resultados:" -ForegroundColor Cyan
    Write-Host "  - Tareas eliminadas: $deleted" -ForegroundColor Green
    if ($failed -gt 0) {
        Write-Host "  - Tareas fallidas: $failed" -ForegroundColor Red
    }
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "ERROR: No se pudo conectar con la API" -ForegroundColor Red
    Write-Host "Detalles: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Asegurate de que:" -ForegroundColor Yellow
    Write-Host "  1. El cluster k3d este corriendo (k3d cluster start todo-app)" -ForegroundColor White
    Write-Host "  2. La API este desplegada y accesible" -ForegroundColor White
    Write-Host "  3. La URL sea correcta (actual: $Target)" -ForegroundColor White
    Write-Host ""
    exit 1
}
