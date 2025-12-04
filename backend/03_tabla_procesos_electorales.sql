-- ===================================================================
-- SISTEMA DE VOTACIÓN DIGITAL - BASE DE DATOS
-- Script 03: Tabla de Procesos Electorales
-- ===================================================================

-- ===================================================================
-- TABLA: PROCESOS DE VOTACIÓN
-- ===================================================================

CREATE TABLE IF NOT EXISTS votacion.procesos_votacion (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    titulo varchar(200) NOT NULL,
    descripcion text,
    
    -- Fechas del proceso
    fecha_inicio timestamptz NOT NULL,
    fecha_cierre timestamptz NOT NULL,
    
    -- Estado del proceso
    estado votacion.estado_proceso DEFAULT 'PENDIENTE',
    
    -- Relación con administrador
    administrador_id uuid NOT NULL,
    
    -- Configuración del proceso
    votos_maximos_por_votante integer DEFAULT 1,
    requiere_verificacion boolean DEFAULT true,
    permite_voto_blanco boolean DEFAULT false,
    mostrar_resultados_parciales boolean DEFAULT false,
    
    -- Estadísticas
    total_votantes_registrados integer DEFAULT 0,
    total_votos_emitidos integer DEFAULT 0,
    
    -- Auditoría
    fecha_creacion timestamptz DEFAULT now(),
    fecha_modificacion timestamptz DEFAULT now(),
    fecha_apertura timestamptz,
    fecha_cierre_real timestamptz,
    fecha_finalizacion timestamptz,
    
    -- Constraints
    CONSTRAINT fk_proceso_administrador 
        FOREIGN KEY (administrador_id) 
        REFERENCES votacion.administradores(id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_fechas_validas 
        CHECK (fecha_cierre > fecha_inicio),
    CONSTRAINT chk_titulo_no_vacio 
        CHECK (length(trim(titulo)) > 0),
    CONSTRAINT chk_votos_maximos 
        CHECK (votos_maximos_por_votante > 0),
    CONSTRAINT chk_totales_positivos 
        CHECK (total_votantes_registrados >= 0 AND total_votos_emitidos >= 0),
    CONSTRAINT chk_votos_consistentes
        CHECK (total_votos_emitidos <= total_votantes_registrados)
);

-- Índices para optimización
CREATE INDEX idx_proceso_estado ON votacion.procesos_votacion(estado);
CREATE INDEX idx_proceso_fecha_inicio ON votacion.procesos_votacion(fecha_inicio);
CREATE INDEX idx_proceso_fecha_cierre ON votacion.procesos_votacion(fecha_cierre);
CREATE INDEX idx_proceso_administrador ON votacion.procesos_votacion(administrador_id);
CREATE INDEX idx_proceso_activo ON votacion.procesos_votacion(estado, fecha_inicio, fecha_cierre);

-- Comentarios
COMMENT ON TABLE votacion.procesos_votacion IS 'Procesos electorales del sistema';
COMMENT ON COLUMN votacion.procesos_votacion.estado IS 'Estado actual del proceso: PENDIENTE, ABIERTO, CERRADO, FINALIZADO';
COMMENT ON COLUMN votacion.procesos_votacion.votos_maximos_por_votante IS 'Número máximo de votos que puede emitir cada votante';
COMMENT ON COLUMN votacion.procesos_votacion.requiere_verificacion IS 'Indica si el votante debe estar verificado para votar';
COMMENT ON COLUMN votacion.procesos_votacion.permite_voto_blanco IS 'Indica si se permite el voto en blanco';
COMMENT ON COLUMN votacion.procesos_votacion.mostrar_resultados_parciales IS 'Indica si se muestran resultados antes del cierre';

-- ===================================================================
-- FUNCIONES PARA GESTIÓN DE PROCESOS
-- ===================================================================

-- Función para validar estado de proceso
CREATE OR REPLACE FUNCTION votacion.validar_estado_proceso()
RETURNS TRIGGER AS $$
BEGIN
    -- Validar transiciones de estado
    IF OLD.estado IS NOT NULL THEN
        -- De PENDIENTE solo puede pasar a ABIERTO
        IF OLD.estado = 'PENDIENTE' AND NEW.estado NOT IN ('PENDIENTE', 'ABIERTO') THEN
            RAISE EXCEPTION 'Un proceso PENDIENTE solo puede pasar a ABIERTO';
        END IF;
        
        -- De ABIERTO solo puede pasar a CERRADO
        IF OLD.estado = 'ABIERTO' AND NEW.estado NOT IN ('ABIERTO', 'CERRADO') THEN
            RAISE EXCEPTION 'Un proceso ABIERTO solo puede pasar a CERRADO';
        END IF;
        
        -- De CERRADO solo puede pasar a FINALIZADO
        IF OLD.estado = 'CERRADO' AND NEW.estado NOT IN ('CERRADO', 'FINALIZADO') THEN
            RAISE EXCEPTION 'Un proceso CERRADO solo puede pasar a FINALIZADO';
        END IF;
        
        -- FINALIZADO es estado terminal
        IF OLD.estado = 'FINALIZADO' AND NEW.estado != 'FINALIZADO' THEN
            RAISE EXCEPTION 'Un proceso FINALIZADO no puede cambiar de estado';
        END IF;
    END IF;
    
    -- Registrar fechas de cambio de estado
    IF NEW.estado = 'ABIERTO' AND OLD.estado != 'ABIERTO' THEN
        NEW.fecha_apertura = now();
    END IF;
    
    IF NEW.estado = 'CERRADO' AND OLD.estado != 'CERRADO' THEN
        NEW.fecha_cierre_real = now();
    END IF;
    
    IF NEW.estado = 'FINALIZADO' AND OLD.estado != 'FINALIZADO' THEN
        NEW.fecha_finalizacion = now();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para validar estado
CREATE TRIGGER trg_validar_estado_proceso
    BEFORE UPDATE ON votacion.procesos_votacion
    FOR EACH ROW
    WHEN (OLD.estado IS DISTINCT FROM NEW.estado)
    EXECUTE FUNCTION votacion.validar_estado_proceso();

-- Trigger para actualizar fecha de modificación
CREATE TRIGGER trg_proceso_fecha_modificacion
    BEFORE UPDATE ON votacion.procesos_votacion
    FOR EACH ROW
    EXECUTE FUNCTION votacion.actualizar_fecha_modificacion();

-- ===================================================================
-- FUNCIÓN PARA ACTUALIZAR ESTADÍSTICAS
-- ===================================================================

CREATE OR REPLACE FUNCTION votacion.actualizar_estadisticas_proceso(p_proceso_id uuid)
RETURNS void AS $$
BEGIN
    UPDATE votacion.procesos_votacion
    SET 
        total_votos_emitidos = (
            SELECT COUNT(DISTINCT votante_id)
            FROM votacion.votos
            WHERE proceso_id = p_proceso_id
        )
    WHERE id = p_proceso_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION votacion.actualizar_estadisticas_proceso IS 'Actualiza las estadísticas de votos de un proceso';

-- ===================================================================
-- INFORMACIÓN
-- ===================================================================

-- Versión: 1.0.0
-- Fecha: 2025-12-04
-- Autor: Yohaldo - Base de Datos
