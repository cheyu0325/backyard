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

    # ==== Extract table name ====
    TABLE_NAME=$(grep "@Table" "$ENTITY_FILE" | sed -n 's/.*name *= *"\([^"]*\)".*/\1/p')
    if [ -z "$TABLE_NAME" ]; then
        TABLE_NAME=$(echo "$ENTITY_NAME" | awk '{print tolower($0)}')
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
import org.springframework.stereotype.Repository;
import ${BASE_PACKAGE}.${ENTITY_NAME};
$IMPORT_ID_CLASS

@Repository
public interface ${ENTITY_NAME}Repository extends JpaRepository<${ENTITY_NAME}, ${ID_TYPE}> {
}
EOF

    # ==== Generate Service Interface ====
    cat > "$SERVICE_FILE" <<EOF
package ${SERVICE_PACKAGE};

import java.util.List;
import java.util.Optional;
import ${BASE_PACKAGE}.${ENTITY_NAME};
$IMPORT_ID_CLASS

public interface ${ENTITY_NAME}Service {
    ${ENTITY_NAME} save(${ENTITY_NAME} entity);
    ${ENTITY_NAME} update(${ENTITY_NAME} entity);
    Optional<${ENTITY_NAME}> findById(${ID_TYPE} id);
    void delete(${ID_TYPE} id);
    List<${ENTITY_NAME}> findByCriteria(${ENTITY_NAME} criteria);

    ${ENTITY_NAME} findByNativeSqlSingle(${ENTITY_NAME} criteriaEntity);
    List<${ENTITY_NAME}> findByNativeSqlList(${ENTITY_NAME} criteriaEntity);
}
EOF

    # ==== Generate Service Implementation ====
    cat > "$SERVICE_IMPL_FILE" <<EOF
package ${SERVICE_IMPL_PACKAGE};

import java.lang.reflect.Field;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.Query;
import jakarta.persistence.criteria.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.beans.factory.annotation.Autowired;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import ${BASE_PACKAGE}.${ENTITY_NAME};
$IMPORT_ID_CLASS
import ${BASE_PACKAGE}.repository.${ENTITY_NAME}Repository;
import ${BASE_PACKAGE}.service.${ENTITY_NAME}Service;

@Service
public class ${ENTITY_NAME}ServiceImpl implements ${ENTITY_NAME}Service {

    private static final Logger logger = LoggerFactory.getLogger(${ENTITY_NAME}ServiceImpl.class);

    @Autowired
    private ${ENTITY_NAME}Repository repository;

    @PersistenceContext
    private EntityManager em;

    private static final Map<Class<?>, List<Field>> FIELD_CACHE = new ConcurrentHashMap<>();

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
    public List<${ENTITY_NAME}> findByCriteria(${ENTITY_NAME} criteriaEntity) {
        logger.debug("Executing Criteria Query for ${ENTITY_NAME}");
        CriteriaBuilder cb = em.getCriteriaBuilder();
        CriteriaQuery<${ENTITY_NAME}> cq = cb.createQuery(${ENTITY_NAME}.class);
        Root<${ENTITY_NAME}> root = cq.from(${ENTITY_NAME}.class);
        List<Predicate> predicates = new ArrayList<>();

        for (Field field : getEntityFields(${ENTITY_NAME}.class)) {
            try {
                Object value = field.get(criteriaEntity);
                if (value != null) {
                    if (field.isAnnotationPresent(jakarta.persistence.EmbeddedId.class)) {
                        for (Field subField : value.getClass().getDeclaredFields()) {
                            subField.setAccessible(true);
                            Object subValue = subField.get(value);
                            if (subValue != null) {
                                predicates.add(cb.equal(root.get(field.getName()).get(subField.getName()), subValue));
                            }
                        }
                    } else {
                        predicates.add(cb.equal(root.get(field.getName()), value));
                    }
                }
            } catch (Exception ignored) {}
        }

        if (!predicates.isEmpty()) {
            cq.where(predicates.toArray(new Predicate[0]));
        }

        return em.createQuery(cq).getResultList();
    }

    private List<Field> getEntityFields(Class<?> clazz) {
        return FIELD_CACHE.computeIfAbsent(clazz, c -> {
            List<Field> fields = new ArrayList<>();
            for (Field f : c.getDeclaredFields()) {
                if (!java.lang.reflect.Modifier.isStatic(f.getModifiers()) &&
                    !java.lang.reflect.Modifier.isTransient(f.getModifiers())) {
                    f.setAccessible(true);
                    fields.add(f);
                }
            }
            return fields;
        });
    }

    private String resolveColumnName(Field field) {
        if (field.isAnnotationPresent(jakarta.persistence.Column.class)) {
            jakarta.persistence.Column col = field.getAnnotation(jakarta.persistence.Column.class);
            if (!col.name().isEmpty()) {
                return col.name();
            }
        }
        return field.getName();
    }

    @Override
    @Transactional(readOnly = true)
    public ${ENTITY_NAME} findByNativeSqlSingle(${ENTITY_NAME} criteriaEntity) {
        logger.debug("Executing Native SQL (Single Result) for ${ENTITY_NAME}");
        StringBuilder sql = new StringBuilder("SELECT * FROM ${TABLE_NAME} WHERE 1=1");
        Map<String, Object> params = new HashMap<>();

        for (Field field : getEntityFields(${ENTITY_NAME}.class)) {
            try {
                Object value = field.get(criteriaEntity);
                if (value != null) {
                    if (field.isAnnotationPresent(jakarta.persistence.EmbeddedId.class)) {
                        for (Field subField : value.getClass().getDeclaredFields()) {
                            subField.setAccessible(true);
                            Object subValue = subField.get(value);
                            if (subValue != null) {
                                String columnName = resolveColumnName(subField);
                                sql.append(" AND ").append(columnName).append(" = :")
                                   .append(field.getName()).append("_").append(subField.getName());
                                params.put(field.getName() + "_" + subField.getName(), subValue);
                            }
                        }
                    } else {
                        String columnName = resolveColumnName(field);
                        sql.append(" AND ").append(columnName).append(" = :").append(field.getName());
                        params.put(field.getName(), value);
                    }
                }
            } catch (Exception ignored) {}
        }

        Query query = em.createNativeQuery(sql.toString(), ${ENTITY_NAME}.class);
        params.forEach(query::setParameter);
        return (${ENTITY_NAME}) query.getSingleResult();
    }

    @Override
    @Transactional(readOnly = true)
    public List<${ENTITY_NAME}> findByNativeSqlList(${ENTITY_NAME} criteriaEntity) {
        logger.debug("Executing Native SQL (List Result) for ${ENTITY_NAME}");
        StringBuilder sql = new StringBuilder("SELECT * FROM ${TABLE_NAME} WHERE 1=1");
        Map<String, Object> params = new HashMap<>();

        for (Field field : getEntityFields(${ENTITY_NAME}.class)) {
            try {
                Object value = field.get(criteriaEntity);
                if (value != null) {
                    if (field.isAnnotationPresent(jakarta.persistence.EmbeddedId.class)) {
                        for (Field subField : value.getClass().getDeclaredFields()) {
                            subField.setAccessible(true);
                            Object subValue = subField.get(value);
                            if (subValue != null) {
                                String columnName = resolveColumnName(subField);
                                sql.append(" AND ").append(columnName).append(" = :")
                                   .append(field.getName()).append("_").append(subField.getName());
                                params.put(field.getName() + "_" + subField.getName(), subValue);
                            }
                        }
                    } else {
                        String columnName = resolveColumnName(field);
                        sql.append(" AND ").append(columnName).append(" = :").append(field.getName());
                        params.put(field.getName(), value);
                    }
                }
            } catch (Exception ignored) {}
        }

        Query query = em.createNativeQuery(sql.toString(), ${ENTITY_NAME}.class);
        params.forEach(query::setParameter);
        return query.getResultList();
    }
}
EOF

    echo "✅ Generated: ${ENTITY_NAME}Repository, ${ENTITY_NAME}Service, ${ENTITY_NAME}ServiceImpl (with SLF4J logger)"
}

for ENTITY_FILE in ${ENTITY_DIR}/*.java; do
    generate_files "$ENTITY_FILE"
done

echo "🎯 Code generation completed successfully!"
