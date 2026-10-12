-- ============================================================================
-- ESQUEMA SQL COMPLETO (DDL) - SISTEMA HÍBRIDO RELACIONAL-VECTORIAL
-- Documentación y Entrega 1: [ruta/schema.sql]
-- ============================================================================

-- 1. HABILITACIÓN DE EXTENSIÓN VECTORIAL
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================================
-- 2. TABLAS RELACIONALES (DISEÑO 3FN)
-- ============================================================================

-- Tabla 1: Usuarios (RF-01)
CREATE TABLE usuarios (
    id_usuario SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    rol VARCHAR(20) NOT NULL CHECK (rol IN ('Admin', 'Usuario', 'Evaluador'))
);

-- Tabla 2: Documentos (RF-02)
CREATE TABLE documentos (
    fuente VARCHAR(255),
    contenido_texto TEXT NOT NULL
);

-- Tabla 3: Imagenes (RF-03)
CREATE TABLE imagenes (
    id_img SERIAL PRIMARY KEY,
    id_doc INT NOT NULL REFERENCES documentos(id_doc) ON DELETE CASCADE,
    ruta_archivo VARCHAR(512) NOT NULL,
    descripcion TEXT
);

-- Tabla 4: Imagen_Etiquetas (Normalización 1FN para etiquetas multivaluadas)
CREATE TABLE imagen_etiquetas (
    id_img INT NOT NULL REFERENCES imagenes(id_img) ON DELETE CASCADE,
    etiqueta VARCHAR(50) NOT NULL,
    PRIMARY KEY (id_img, etiqueta)
);

-- Tabla 5: Consultas (RF-04)
CREATE TABLE consultas (
    id_consulta SERIAL PRIMARY KEY,
    texto_pregunta TEXT NOT NULL,
    fecha TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    id_usuario INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE RESTRICT
);

-- Tabla 6: Resultados (RF-11)
CREATE TABLE resultados (
    id_resultado SERIAL PRIMARY KEY,
    id_consulta INT NOT NULL REFERENCES consultas(id_consulta) ON DELETE CASCADE,
    id_doc INT REFERENCES documentos(id_doc) ON DELETE CASCADE,
    id_img INT REFERENCES imagenes(id_img) ON DELETE CASCADE,
    score_similitud FLOAT NOT NULL,
    CONSTRAINT chk_resultado_destino CHECK (id_doc IS NOT NULL OR id_img IS NOT NULL)
);

-- Tabla 7: Evaluaciones (RF-13, RF-14, Relación 1:1 con Consultas)
CREATE TABLE evaluaciones (
    id_eval SERIAL PRIMARY KEY,
    id_consulta INT NOT NULL UNIQUE REFERENCES consultas(id_consulta) ON DELETE CASCADE,
    faithfulness FLOAT CHECK (faithfulness BETWEEN 0.0 AND 1.0),
    answer_relevancy FLOAT CHECK (answer_relevancy BETWEEN 0.0 AND 1.0),
    context_recall FLOAT CHECK (context_recall BETWEEN 0.0 AND 1.0),
    modelo_eval VARCHAR(100) NOT NULL,
    fecha TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 3. TABLAS VECTORIALES (PGVECTOR)
-- ============================================================================

-- Tabla 8: Embeddings_Texto (Estructura exacta solicitada por el docente)
CREATE TABLE embeddings_texto (
    id_embedding SERIAL PRIMARY KEY,
    id_doc INT NOT NULL REFERENCES documentos(id_doc) ON DELETE CASCADE,
    chunk_id INT NOT NULL,
    estrategia_chunking VARCHAR(20) NOT NULL 
        CHECK (estrategia_chunking IN ('fixed-size', 'sentence-aware', 'semantic')),
    chunk_texto TEXT NOT NULL,
    vector_embedding VECTOR(384) NOT NULL,
    modelo VARCHAR(100) NOT NULL,
    UNIQUE (id_doc, estrategia_chunking, chunk_id)
);

-- Tabla 9: Embeddings_Imagen (Estructura exacta solicitada por el docente)
CREATE TABLE embeddings_imagen (
    id_embedding SERIAL PRIMARY KEY,
    id_img INT NOT NULL REFERENCES imagenes(id_img) ON DELETE CASCADE,
    vector_embedding VECTOR(512) NOT NULL,
    modelo VARCHAR(100) NOT NULL
);

-- Tabla 10: QueryEmbeddings (Vectorización de preguntas del usuario)
CREATE TABLE query_embeddings (
    id_qemb SERIAL PRIMARY KEY,
    id_consulta INT NOT NULL REFERENCES consultas(id_consulta) ON DELETE CASCADE,
    vector_embedding VECTOR(384) NOT NULL,
    modelo VARCHAR(100) NOT NULL
);

-- ============================================================================
-- 4. ÍNDICES VECTORIALES (HNSW)
-- ============================================================================
CREATE INDEX ON embeddings_texto USING hnsw (vector_embedding vector_cosine_ops);
CREATE INDEX ON embeddings_imagen USING hnsw (vector_embedding vector_cosine_ops);
CREATE INDEX ON query_embeddings USING hnsw (vector_embedding vector_cosine_ops);

-- ÍNDICES RELACIONALES ADICIONALES PARA BÚSQUEDA RÁPIDA
CREATE INDEX idx_documentos_idioma_fecha ON documentos(idioma, fecha);
CREATE INDEX idx_imagen_etiquetas_etiqueta ON imagen_etiquetas(etiqueta);