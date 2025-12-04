-- ===================================================================
-- SISTEMA DE VOTACIÓN DIGITAL - BASE DE DATOS
-- Script 02: Tablas de Usuarios y Roles
-- ===================================================================

-- ===================================================================
-- TABLA: ADMINISTRADORES
-- ===================================================================

CREATE TABLE IF NOT EXISTS votacion.administradores (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario varchar(50) UNIQUE NOT NULL,
    contrasena text NOT NULL,
    nombre_completo varchar(200) NOT NULL,
    email varchar(150) UNIQUE NOT NULL,
    telefono varchar(20),
    activo boolean DEFAULT true,
    ultimo_acceso timestamptz,
    intentos_fallidos integer DEFAULT 0,
    bloqueado_hasta timestamptz,
    fecha_creacion timestamptz DEFAULT now(),
    fecha_modificacion timestamptz DEFAULT now(),
    
    -- Constraints
    CONSTRAINT chk_email_admin_formato CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_usuario_longitud CHECK (length(usuario) >= 4),
    CONSTRAINT chk_intentos_positivo CHECK (intentos_fallidos >= 0)
);

-- Índices para optimización
CREATE INDEX idx_admin_usuario ON votacion.administradores(usuario);
CREATE INDEX idx_admin_email ON votacion.administradores(email);
CREATE INDEX idx_admin_activo ON votacion.administradores(activo);

-- Comentarios
COMMENT ON TABLE votacion.administradores IS 'Usuarios administradores del sistema de votación';
COMMENT ON COLUMN votacion.administradores.usuario IS 'Nombre de usuario único para login';
COMMENT ON COLUMN votacion.administradores.contrasena IS 'Contraseña hasheada con bcrypt';
COMMENT ON COLUMN votacion.administradores.intentos_fallidos IS 'Contador de intentos de login fallidos';
COMMENT ON COLUMN votacion.administradores.bloqueado_hasta IS 'Fecha hasta la cual el usuario está bloqueado';

-- ===================================================================
-- TABLA: VOTANTES
-- ===================================================================

CREATE TABLE IF NOT EXISTS votacion.votantes (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    dni varchar(20) UNIQUE NOT NULL,
    contrasena text NOT NULL,
    nombre_completo varchar(200) NOT NULL,
    email varchar(150),
    telefono varchar(20),
    fecha_nacimiento date,
    direccion text,
    activo boolean DEFAULT true,
    verificado boolean DEFAULT false,
    ultimo_acceso timestamptz,
    intentos_fallidos integer DEFAULT 0,
    bloqueado_hasta timestamptz,
    fecha_registro timestamptz DEFAULT now(),
    fecha_modificacion timestamptz DEFAULT now(),
    
    -- Constraints
    CONSTRAINT chk_dni_formato CHECK (dni ~ '^[0-9]{8,20}$'),
    CONSTRAINT chk_email_votante_formato CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_fecha_nacimiento CHECK (fecha_nacimiento < CURRENT_DATE),
    CONSTRAINT chk_edad_minima CHECK (fecha_nacimiento IS NULL OR fecha_nacimiento <= CURRENT_DATE - INTERVAL '18 years'),
    CONSTRAINT chk_intentos_votante_positivo CHECK (intentos_fallidos >= 0)
);

-- Índices para optimización
CREATE INDEX idx_votante_dni ON votacion.votantes(dni);
CREATE INDEX idx_votante_email ON votacion.votantes(email);
CREATE INDEX idx_votante_activo ON votacion.votantes(activo);
CREATE INDEX idx_votante_verificado ON votacion.votantes(verificado);

-- Comentarios
COMMENT ON TABLE votacion.votantes IS 'Usuarios votantes del sistema electoral';
COMMENT ON COLUMN votacion.votantes.dni IS 'Documento Nacional de Identidad único';
COMMENT ON COLUMN votacion.votantes.contrasena IS 'Contraseña hasheada con bcrypt';
COMMENT ON COLUMN votacion.votantes.verificado IS 'Indica si el votante ha verificado su email';
COMMENT ON COLUMN votacion.votantes.intentos_fallidos IS 'Contador de intentos de login fallidos';

-- ===================================================================
-- FUNCIONES AUXILIARES
-- ===================================================================

-- Función para actualizar fecha de modificación
CREATE OR REPLACE FUNCTION votacion.actualizar_fecha_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_modificacion = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para actualizar fecha de modificación
CREATE TRIGGER trg_admin_fecha_modificacion
    BEFORE UPDATE ON votacion.administradores
    FOR EACH ROW
    EXECUTE FUNCTION votacion.actualizar_fecha_modificacion();

CREATE TRIGGER trg_votante_fecha_modificacion
    BEFORE UPDATE ON votacion.votantes
    FOR EACH ROW
    EXECUTE FUNCTION votacion.actualizar_fecha_modificacion();

-- ===================================================================
-- INFORMACIÓN
-- ===================================================================

-- Versión: 1.0.0
-- Fecha: 2025-12-04
-- Autor: Yohaldo - Base de Datos
