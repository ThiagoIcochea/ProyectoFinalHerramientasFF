-- ===================================================================
-- SISTEMA DE VOTACIÓN DIGITAL - BASE DE DATOS
-- Script 04: Tabla de Candidatos
-- ===================================================================

-- ===================================================================
-- TABLA: CANDIDATOS
-- ===================================================================

CREATE TABLE IF NOT EXISTS votacion.candidatos (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Información básica
    nombre varchar(200) NOT NULL,
    descripcion text,
    propuestas text,
    biografia text,
    
    -- Multimedia
    avatar_url text,
    foto_principal_url text,
    video_presentacion_url text,
    
    -- Relación con proceso
    proceso_id uuid NOT NULL,
    
    -- Información adicional
    partido_politico varchar(150),
    numero_lista integer,
    simbolo_url text,
    color_campana varchar(7), -- Color hexadecimal #RRGGBB
    
    -- Estado
    activo boolean DEFAULT true,
    aprobado boolean DEFAULT false,
    
    -- Estadísticas
    total_votos integer DEFAULT 0,
    porcentaje_votos numeric(5,2) DEFAULT 0.00,
    
    -- Auditoría
    fecha_registro timestamptz DEFAULT now(),
    fecha_modificacion timestamptz DEFAULT now(),
    fecha_aprobacion timestamptz,
    aprobado_por uuid,
    
    -- Constraints
    CONSTRAINT fk_candidato_proceso 
        FOREIGN KEY (proceso_id) 
        REFERENCES votacion.procesos_votacion(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_candidato_aprobador
        FOREIGN KEY (aprobado_por)
        REFERENCES votacion.administradores(id)
        ON DELETE SET NULL,
    CONSTRAINT chk_nombre_no_vacio 
        CHECK (length(trim(nombre)) > 0),
    CONSTRAINT chk_numero_lista_positivo 
        CHECK (numero_lista IS NULL OR numero_lista > 0),
    CONSTRAINT chk_color_formato 
        CHECK (color_campana IS NULL OR color_campana ~ '^#[0-9A-Fa-f]{6}$'),
    CONSTRAINT chk_total_votos_positivo 
        CHECK (total_votos >= 0),
    CONSTRAINT chk_porcentaje_valido 
        CHECK (porcentaje_votos >= 0 AND porcentaje_votos <= 100)
);

-- Índices para optimización
CREATE INDEX idx_candidato_proceso ON votacion.candidatos(proceso_id);
CREATE INDEX idx_candidato_activo ON votacion.candidatos(activo);
CREATE INDEX idx_candidato_aprobado ON votacion.candidatos(aprobado);
CREATE INDEX idx_candidato_numero_lista ON votacion.candidatos(proceso_id, numero_lista);
CREATE INDEX idx_candidato_votos ON votacion.candidatos(total_votos DESC);

-- Índice único para número de lista por proceso
CREATE UNIQUE INDEX idx_candidato_numero_unico 
    ON votacion.candidatos(proceso_id, numero_lista) 
    WHERE numero_lista IS NOT NULL;

-- Comentarios
COMMENT ON TABLE votacion.candidatos IS 'Candidatos participantes en los procesos electorales';
COMMENT ON COLUMN votacion.candidatos.propuestas IS 'Propuestas principales del candidato';
COMMENT ON COLUMN votacion.candidatos.numero_lista IS 'Número de lista del candidato en el proceso';
COMMENT ON COLUMN votacion.candidatos.color_campana IS 'Color de campaña en formato hexadecimal';
COMMENT ON COLUMN votacion.candidatos.aprobado IS 'Indica si el candidato fue aprobado por un administrador';
COMMENT ON COLUMN votacion.candidatos.total_votos IS 'Total de votos recibidos (actualizado por trigger)';
COMMENT ON COLUMN votacion.candidatos.porcentaje_votos IS 'Porcentaje de votos sobre el total';

-- ===================================================================
-- FUNCIONES PARA GESTIÓN DE CANDIDATOS
-- ===================================================================

-- Función para validar candidato antes de insertar/actualizar
CREATE OR REPLACE FUNCTION votacion.validar_candidato()
RETURNS TRIGGER AS $$
DECLARE
    v_estado_proceso votacion.estado_proceso;
BEGIN
    -- Obtener estado del proceso
    SELECT estado INTO v_estado_proceso
    FROM votacion.procesos_votacion
    WHERE id = NEW.proceso_id;
    
    -- No permitir agregar candidatos a procesos CERRADOS o FINALIZADOS
    IF TG_OP = 'INSERT' AND v_estado_proceso IN ('CERRADO', 'FINALIZADO') THEN
        RAISE EXCEPTION 'No se pueden agregar candidatos a un proceso cerrado o finalizado';
    END IF;
    
    -- No permitir eliminar candidatos de procesos ABIERTOS
    IF TG_OP = 'DELETE' AND v_estado_proceso = 'ABIERTO' THEN
        RAISE EXCEPTION 'No se pueden eliminar candidatos de un proceso abierto';
    END IF;
    
    -- Registrar fecha de aprobación
    IF TG_OP = 'UPDATE' AND NEW.aprobado = true AND OLD.aprobado = false THEN
        NEW.fecha_aprobacion = now();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para validar candidato
CREATE TRIGGER trg_validar_candidato
    BEFORE INSERT OR UPDATE ON votacion.candidatos
    FOR EACH ROW
    EXECUTE FUNCTION votacion.validar_candidato();

-- Trigger para actualizar fecha de modificación
CREATE TRIGGER trg_candidato_fecha_modificacion
    BEFORE UPDATE ON votacion.candidatos
    FOR EACH ROW
    EXECUTE FUNCTION votacion.actualizar_fecha_modificacion();

-- ===================================================================
-- FUNCIÓN PARA ACTUALIZAR PORCENTAJES
-- ===================================================================

CREATE OR REPLACE FUNCTION votacion.actualizar_porcentajes_candidatos(p_proceso_id uuid)
RETURNS void AS $$
DECLARE
    v_total_votos integer;
BEGIN
    -- Obtener total de votos del proceso
    SELECT COUNT(*) INTO v_total_votos
    FROM votacion.votos
    WHERE proceso_id = p_proceso_id;
    
    -- Actualizar porcentajes de cada candidato
    IF v_total_votos > 0 THEN
        UPDATE votacion.candidatos c
        SET porcentaje_votos = ROUND((c.total_votos::numeric / v_total_votos) * 100, 2)
        WHERE c.proceso_id = p_proceso_id;
    ELSE
        UPDATE votacion.candidatos
        SET porcentaje_votos = 0
        WHERE proceso_id = p_proceso_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION votacion.actualizar_porcentajes_candidatos IS 'Actualiza los porcentajes de votos de todos los candidatos de un proceso';

-- ===================================================================
-- INFORMACIÓN
-- ===================================================================

-- Versión: 1.0.0
-- Fecha: 2025-12-04
-- Autor: Yohaldo - Base de Datos
