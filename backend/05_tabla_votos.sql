-- ===================================================================
-- SISTEMA DE VOTACIÓN DIGITAL - BASE DE DATOS
-- Script 05: Tabla de Votos y Sistema de Votación
-- ===================================================================

-- ===================================================================
-- TABLA: VOTOS
-- ===================================================================

CREATE TABLE IF NOT EXISTS votacion.votos (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Relaciones principales
    proceso_id uuid NOT NULL,
    votante_id uuid NOT NULL,
    candidato_id uuid NOT NULL,
    
    -- Información del voto
    fecha_voto timestamptz DEFAULT now(),
    
    -- Auditoría y seguridad
    ip_address inet,
    user_agent text,
    hash_voto varchar(64), -- Hash SHA256 para verificación
    
    -- Metadatos
    tiempo_decision_segundos integer, -- Tiempo que tomó decidir el voto
    dispositivo varchar(50), -- desktop, mobile, tablet
    
    -- Constraints
    CONSTRAINT fk_voto_proceso 
        FOREIGN KEY (proceso_id) 
        REFERENCES votacion.procesos_votacion(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_voto_votante 
        FOREIGN KEY (votante_id) 
        REFERENCES votacion.votantes(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_voto_candidato 
        FOREIGN KEY (candidato_id) 
        REFERENCES votacion.candidatos(id)
        ON DELETE RESTRICT,
    
    -- Un votante solo puede votar una vez por proceso
    CONSTRAINT uk_voto_unico 
        UNIQUE(proceso_id, votante_id),
    
    CONSTRAINT chk_tiempo_decision 
        CHECK (tiempo_decision_segundos IS NULL OR tiempo_decision_segundos > 0)
);

-- Índices para optimización
CREATE INDEX idx_voto_proceso ON votacion.votos(proceso_id);
CREATE INDEX idx_voto_votante ON votacion.votos(votante_id);
CREATE INDEX idx_voto_candidato ON votacion.votos(candidato_id);
CREATE INDEX idx_voto_fecha ON votacion.votos(fecha_voto);
CREATE INDEX idx_voto_proceso_fecha ON votacion.votos(proceso_id, fecha_voto);

-- Comentarios
COMMENT ON TABLE votacion.votos IS 'Registro de votos emitidos en los procesos electorales';
COMMENT ON COLUMN votacion.votos.hash_voto IS 'Hash SHA256 del voto para verificación de integridad';
COMMENT ON COLUMN votacion.votos.tiempo_decision_segundos IS 'Tiempo que el votante tardó en decidir (analítica)';
COMMENT ON COLUMN votacion.votos.dispositivo IS 'Tipo de dispositivo desde el que se votó';

-- ===================================================================
-- FUNCIONES PARA GESTIÓN DE VOTOS
-- ===================================================================

-- Función para validar voto antes de insertar
CREATE OR REPLACE FUNCTION votacion.validar_voto()
RETURNS TRIGGER AS $$
DECLARE
    v_estado_proceso votacion.estado_proceso;
    v_fecha_inicio timestamptz;
    v_fecha_cierre timestamptz;
    v_votante_activo boolean;
    v_candidato_activo boolean;
    v_candidato_aprobado boolean;
    v_candidato_del_proceso uuid;
BEGIN
    -- Verificar estado del proceso
    SELECT estado, fecha_inicio, fecha_cierre
    INTO v_estado_proceso, v_fecha_inicio, v_fecha_cierre
    FROM votacion.procesos_votacion
    WHERE id = NEW.proceso_id;
    
    -- El proceso debe estar ABIERTO
    IF v_estado_proceso != 'ABIERTO' THEN
        RAISE EXCEPTION 'El proceso electoral no está abierto para votación';
    END IF;
    
    -- Verificar que estamos dentro del período de votación
    IF now() < v_fecha_inicio THEN
        RAISE EXCEPTION 'El proceso electoral aún no ha iniciado';
    END IF;
    
    IF now() > v_fecha_cierre THEN
        RAISE EXCEPTION 'El proceso electoral ya ha cerrado';
    END IF;
    
    -- Verificar que el votante esté activo
    SELECT activo INTO v_votante_activo
    FROM votacion.votantes
    WHERE id = NEW.votante_id;
    
    IF NOT v_votante_activo THEN
        RAISE EXCEPTION 'El votante no está activo en el sistema';
    END IF;
    
    -- Verificar que el candidato esté activo, aprobado y pertenezca al proceso
    SELECT activo, aprobado, proceso_id
    INTO v_candidato_activo, v_candidato_aprobado, v_candidato_del_proceso
    FROM votacion.candidatos
    WHERE id = NEW.candidato_id;
    
    IF NOT v_candidato_activo THEN
        RAISE EXCEPTION 'El candidato no está activo';
    END IF;
    
    IF NOT v_candidato_aprobado THEN
        RAISE EXCEPTION 'El candidato no está aprobado para recibir votos';
    END IF;
    
    IF v_candidato_del_proceso != NEW.proceso_id THEN
        RAISE EXCEPTION 'El candidato no pertenece a este proceso electoral';
    END IF;
    
    -- Generar hash del voto (para verificación posterior)
    NEW.hash_voto = encode(
        digest(
            NEW.proceso_id::text || 
            NEW.votante_id::text || 
            NEW.candidato_id::text || 
            NEW.fecha_voto::text,
            'sha256'
        ),
        'hex'
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para validar voto
CREATE TRIGGER trg_validar_voto
    BEFORE INSERT ON votacion.votos
    FOR EACH ROW
    EXECUTE FUNCTION votacion.validar_voto();

-- ===================================================================
-- FUNCIÓN PARA ACTUALIZAR CONTADORES DESPUÉS DE VOTAR
-- ===================================================================

CREATE OR REPLACE FUNCTION votacion.actualizar_contadores_voto()
RETURNS TRIGGER AS $$
BEGIN
    -- Actualizar contador de votos del candidato
    UPDATE votacion.candidatos
    SET total_votos = total_votos + 1
    WHERE id = NEW.candidato_id;
    
    -- Actualizar estadísticas del proceso
    PERFORM votacion.actualizar_estadisticas_proceso(NEW.proceso_id);
    
    -- Actualizar porcentajes de candidatos
    PERFORM votacion.actualizar_porcentajes_candidatos(NEW.proceso_id);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para actualizar contadores
CREATE TRIGGER trg_actualizar_contadores_voto
    AFTER INSERT ON votacion.votos
    FOR EACH ROW
    EXECUTE FUNCTION votacion.actualizar_contadores_voto();

-- ===================================================================
-- FUNCIÓN PARA VERIFICAR SI UN VOTANTE YA VOTÓ
-- ===================================================================

CREATE OR REPLACE FUNCTION votacion.verificar_voto_existente(
    p_proceso_id uuid,
    p_votante_id uuid
)
RETURNS boolean AS $$
DECLARE
    v_existe boolean;
BEGIN
    SELECT EXISTS(
        SELECT 1 
        FROM votacion.votos
        WHERE proceso_id = p_proceso_id
        AND votante_id = p_votante_id
    ) INTO v_existe;
    
    RETURN v_existe;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION votacion.verificar_voto_existente IS 'Verifica si un votante ya emitió su voto en un proceso';

-- ===================================================================
-- INFORMACIÓN
-- ===================================================================

-- Versión: 1.0.0
-- Fecha: 2025-12-04
-- Autor: Yohaldo - Base de Datos
