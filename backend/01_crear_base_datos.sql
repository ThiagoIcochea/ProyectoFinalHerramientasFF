-- ===================================================================
-- SISTEMA DE VOTACIÓN DIGITAL - BASE DE DATOS
-- Script 01: Creación de Base de Datos y Configuración Inicial
-- ===================================================================

-- Crear la base de datos si no existe
-- NOTA: Ejecutar este comando como superusuario (postgres)
-- CREATE DATABASE sistema_votacion_db;

-- Conectar a la base de datos
-- \c sistema_votacion_db;

-- ===================================================================
-- EXTENSIONES NECESARIAS
-- ===================================================================

-- Extensión para generación de UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Extensión para encriptación (opcional, para futuras mejoras)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ===================================================================
-- CONFIGURACIONES INICIALES
-- ===================================================================

-- Configurar zona horaria
SET timezone = 'America/Lima';

-- Crear esquema para el sistema de votación
CREATE SCHEMA IF NOT EXISTS votacion;

-- Comentarios del esquema
COMMENT ON SCHEMA votacion IS 'Esquema principal del sistema de votación digital';

-- ===================================================================
-- TIPOS ENUMERADOS
-- ===================================================================

-- Estado de procesos de votación
CREATE TYPE votacion.estado_proceso AS ENUM (
    'PENDIENTE',    -- Proceso creado pero no iniciado
    'ABIERTO',      -- Proceso activo, votación en curso
    'CERRADO',      -- Proceso cerrado, ya no se puede votar
    'FINALIZADO'    -- Proceso finalizado con resultados publicados
);

-- Tipos de acciones para auditoría
CREATE TYPE votacion.tipo_accion AS ENUM (
    'LOGIN',
    'LOGOUT',
    'CREAR',
    'EDITAR',
    'ELIMINAR',
    'VOTAR',
    'ABRIR_PROCESO',
    'CERRAR_PROCESO',
    'FINALIZAR_PROCESO',
    'CONSULTAR'
);

-- Tipos de entidad para auditoría
CREATE TYPE votacion.tipo_entidad AS ENUM (
    'SISTEMA',
    'USUARIO',
    'ADMINISTRADOR',
    'VOTANTE',
    'PROCESO',
    'CANDIDATO',
    'VOTO'
);

-- ===================================================================
-- COMENTARIOS
-- ===================================================================

COMMENT ON TYPE votacion.estado_proceso IS 'Estados posibles de un proceso electoral';
COMMENT ON TYPE votacion.tipo_accion IS 'Tipos de acciones registradas en auditoría';
COMMENT ON TYPE votacion.tipo_entidad IS 'Tipos de entidades del sistema';

-- ===================================================================
-- INFORMACIÓN
-- ===================================================================

-- Este script debe ejecutarse primero antes de crear las tablas
-- Versión: 1.0.0
-- Fecha: 2025-12-04
-- Autor: Yohaldo - Base de Datos
