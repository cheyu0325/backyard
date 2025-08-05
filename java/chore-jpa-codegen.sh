#!/bin/bash

# ==== CONFIGURATION ====
BASE_PACKAGE="com.cheyu.fz2h.app.model"
ENTITY_DIR="."
OUTPUT_DIR="."

REPO_PACKAGE="${BASE_PACKAGE}.repository"
SERVICE_PACKAGE="${BASE_PACKAGE}.service"
SERVICE_IMPL_PACKAGE="${BASE_PACKAGE}.service.impl"

REPO_DIR="${OUTPUT_DIR}/repository"
SERVICE_DIR="${OUTPUT_DIR}/service"
SERVICE_IMPL_DIR="${OUTPUT_DIR}/service/impl"

# Create output directories if they don't exist
mkdir -p "$REPO_DIR" "$SERVICE_DIR" "$SERVICE_IMPL_DIR"

echo "🚀 Generating Repository and Service classes from entities in ${ENTITY_DIR}"

generate_files() {
    ENTITY_FILE=$1
    ENTITY_NAME=$(basename "$ENTITY_FILE" .java)

    # ==== Extract ID type ====
    ID_TYPE=$(awk '
    /@Id/ {found=1; next}
    found && /private/ {match($0,/private[[:space:]]+([^[:space:]]+)[[:space:]]+/,a); print a[1]; exit}
    ' "$ENTITY_FILE")

    if [ -z "$ID_TYPE" ]; then
        ID_TYPE=$(awk '
        /@EmbeddedId/ {found=1; next}
        found && /private/ {match($0,/private[[:space:]]+([^[:space:]]+)[[:space:]]+/,a); print a[1]; exit}
        ' "$ENTITY_FILE")
    fi

    if [ -z "$ID_TYPE" ]; then
        echo "⚠️ WARNING: No @Id or @EmbeddedId found in $ENTITY_NAME. Skipping."
        return
    fi

    # ==== Determine file paths ====
    REPO_FILE="${REPO_DIR}/${ENTITY_NAME}Repository.java"
    SERVICE_FILE="${SERVICE_DIR}/${ENTITY_NAME}Service.java"
    SERVICE_IMPL_FILE="${SERVICE_IMPL_DIR}/${ENTITY_NAME}ServiceImpl.java"

    # ==== Skip existing files ====
    if [[ -f "$REPO_FILE" || -f "$SERVICE_FILE" || -f "$SERVICE_IMPL_FILE" ]]; then
        echo "⚠️ Skipping ${ENTITY_NAME}: Repository or Service already exists."
        return
    fi

    # ==== Handle EmbeddedId import ====
    IMPORT_ID_CLASS=""
    if [[ "$ID_TYPE" != "Long" && "$ID_TYPE" != "Integer" && "$ID_TYPE" != "String" ]]; then
        IMPORT_ID_CLASS="import ${BASE_PACKAGE}.${ID_TYPE};"
    fi

    # ==== Generate Repository ====
    cat > "$REPO_FILE" <<EOF
package ${REPO_PACKAGE};

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;
import ${BASE_PACKAGE}.${ENTITY_NAME};
$IMPORT_ID_CLASS

@Repository
public interface ${ENTITY_NAME}Repository extends JpaRepository<${ENTITY_NAME}, ${ID_TYPE}>, JpaSpecificationExecutor<${ENTITY_NAME}> {
}
EOF

    # ==== Generate Service Interface ====
    cat > "$SERVICE_FILE" <<EOF
package ${SERVICE_PACKAGE};

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.domain.Specification;
import ${BASE_PACKAGE}.${ENTITY_NAME};
$IMPORT_ID_CLASS

public interface ${ENTITY_NAME}Service {
    ${ENTITY_NAME} save(${ENTITY_NAME} entity);
    ${ENTITY_NAME} update(${ENTITY_NAME} entity);
    Optional<${ENTITY_NAME}> findById(${ID_TYPE} id);
    void delete(${ID_TYPE} id);
    
    // 方法重載：使用 POJO 物件作為查詢範例
    List<${ENTITY_NAME}> findByCriteria(Object criteria);

    // 方法重載：直接傳入 JPA Specification
    List<${ENTITY_NAME}> findByCriteria(Specification<${ENTITY_NAME}> spec);
}
EOF

    # ==== Generate Service Implementation ====
    cat > "$SERVICE_IMPL_FILE" <<EOF
package ${SERVICE_IMPL_PACKAGE};

import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.beans.factory.annotation.Autowired;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.jpa.domain.Specification;
import ${BASE_PACKAGE}.${ENTITY_NAME};
$IMPORT_ID_CLASS
import ${BASE_PACKAGE}.repository.${ENTITY_NAME}Repository;
import ${BASE_PACKAGE}.service.${ENTITY_NAME}Service;
import ${BASE_PACKAGE}.CriteriaQueryBuilder;

@Service
public class ${ENTITY_NAME}ServiceImpl implements ${ENTITY_NAME}Service {

    private static final Logger logger = LoggerFactory.getLogger(${ENTITY_NAME}ServiceImpl.class);

    @Autowired
    private ${ENTITY_NAME}Repository repository;

    @Override
    @Transactional
    public ${ENTITY_NAME} save(${ENTITY_NAME} entity) {
        logger.info("Saving ${ENTITY_NAME}: {}", entity);
        return repository.save(entity);
    }

    @Override
    @Transactional
    public ${ENTITY_NAME} update(${ENTITY_NAME} entity) {
        logger.info("Updating ${ENTITY_NAME}: {}", entity);
        return repository.save(entity);
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<${ENTITY_NAME}> findById(${ID_TYPE} id) {
        logger.debug("Finding ${ENTITY_NAME} by ID: {}", id);
        return repository.findById(id);
    }

    @Override
    @Transactional
    public void delete(${ID_TYPE} id) {
        logger.warn("Deleting ${ENTITY_NAME} by ID: {}", id);
        repository.deleteById(id);
    }

    @Override
    @Transactional(readOnly = true)
    public List<${ENTITY_NAME}> findByCriteria(Object criteria) {
        logger.info("Finding ${ENTITY_NAME} by criteria: {}", criteria);
        return repository.findAll(CriteriaQueryBuilder.<${ENTITY_NAME}>newQuery().fromExample(criteria).build());
    }

    @Override
    @Transactional(readOnly = true)
    public List<${ENTITY_NAME}> findByCriteria(Specification<${ENTITY_NAME}> spec) {
        logger.info("Finding ${ENTITY_NAME} by custom Specification");
        return repository.findAll(spec);
    }
}
EOF

    echo "✅ Generated: ${ENTITY_NAME}Repository, ${ENTITY_NAME}Service, ${ENTITY_NAME}ServiceImpl (with SLF4J logger and CriteriaQueryBuilder integration)"
}

for ENTITY_FILE in ${ENTITY_DIR}/*.java; do
    if [ -f "$ENTITY_FILE" ]; then
        generate_files "$ENTITY_FILE"
    fi
done

echo "🎯 Code generation completed successfully!"