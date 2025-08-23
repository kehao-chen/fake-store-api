# ArchUnit 實作範例

本文件提供 Fake Store API 專案中 ArchUnit 的具體實作範例，展示如何透過架構測試確保程式碼符合設計原則。

## 📦 依賴配置

### Gradle 依賴
```gradle
dependencies {
    // ArchUnit 核心依賴
    testImplementation 'com.tngtech.archunit:archunit:1.2.1'
    testImplementation 'com.tngtech.archunit:archunit-junit5:1.2.1'
    
    // Spring Boot 測試支援
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    
    // 測試容器支援
    testImplementation 'org.testcontainers:junit-jupiter'
    testImplementation 'org.testcontainers:postgresql'
}
```

### Maven 依賴
```xml
<dependencies>
    <dependency>
        <groupId>com.tngtech.archunit</groupId>
        <artifactId>archunit-junit5</artifactId>
        <version>1.2.1</version>
        <scope>test</scope>
    </dependency>
</dependencies>
```

## 🏗️ 基礎架構測試類

### ArchitectureBaseTest.java
```java
package com.fakestore.architecture;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import org.junit.jupiter.api.TestInstance;

/**
 * ArchUnit 架構測試基礎類
 * 提供共用的 JavaClasses 和架構描述符
 */
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
public abstract class ArchitectureBaseTest {
    
    /**
     * 載入專案的所有類別 (排除測試類別)
     */
    protected static final JavaClasses importedClasses = 
        new ClassFileImporter()
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_JARS)
            .importPackages("com.fakestore");
            
    /**
     * 領域模組清單
     */
    protected static final String[] DOMAIN_PACKAGES = {
        "..product..",
        "..cart..",
        "..order..",
        "..user..",
        "..payment.."
    };
    
    /**
     * 基礎設施模組清單
     */
    protected static final String[] INFRASTRUCTURE_PACKAGES = {
        "..config..",
        "..common..",
        "..security..",
        "..cache.."
    };
}
```

## 🎯 領域邊界測試

### DomainBoundaryTest.java
```java
package com.fakestore.architecture;

import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.*;

/**
 * 領域邊界測試
 * 確保各領域間的依賴符合 DDD 原則
 */
@AnalyzeClasses(packages = "com.fakestore")
@DisplayName("領域邊界架構測試")
class DomainBoundaryTest extends ArchitectureBaseTest {
    
    @ArchTest
    @DisplayName("產品領域不應依賴購物車領域")
    static final ArchRule product_should_not_depend_on_cart =
        noClasses()
            .that().resideInAPackage("..product..")
            .should().dependOnClassesThat()
            .resideInAPackage("..cart..")
            .because("產品領域應保持獨立，不依賴購物車領域");
    
    @ArchTest
    @DisplayName("購物車領域不應依賴訂單領域") 
    static final ArchRule cart_should_not_depend_on_order =
        noClasses()
            .that().resideInAPackage("..cart..")
            .should().dependOnClassesThat()
            .resideInAPackage("..order..")
            .because("購物車與訂單應透過領域事件通訊");
    
    @ArchTest
    @DisplayName("使用者領域不應依賴業務領域")
    static final ArchRule user_should_not_depend_on_business_domains =
        noClasses()
            .that().resideInAPackage("..user..")
            .should().dependOnClassesThat()
            .resideInAPackage("..product..")
            .orShould().dependOnClassesThat()
            .resideInAPackage("..cart..")
            .orShould().dependOnClassesThat()
            .resideInAPackage("..order..")
            .because("使用者領域應保持純淨，不依賴具體業務邏輯");
    
    @Test
    @DisplayName("支付領域只能透過定義的介面與外部通訊")
    void paymentDomainShouldOnlyCommunicateThroughDefinedInterfaces() {
        noClasses()
            .that().resideInAPackage("..payment..")
            .should().dependOnClassesThat()
            .resideInAPackage("..product..")
            .orShould().dependOnClassesThat()
            .resideInAPackage("..cart..")
            .because("支付領域應透過領域服務或事件與其他領域通訊")
            .check(importedClasses);
    }
    
    @Test 
    @DisplayName("所有領域都可以使用共通基礎設施")
    void domainsShouldBeAbleToUseCommonInfrastructure() {
        // 這是正面測試，確保領域可以使用基礎設施
        classes()
            .that().resideInAnyPackage(DOMAIN_PACKAGES)
            .should().onlyDependOnClassesThat()
            .resideInAnyPackage(DOMAIN_PACKAGES)
            .or().resideInAnyPackage(INFRASTRUCTURE_PACKAGES)
            .or().resideInAnyPackage("java..")
            .or().resideInAnyPackage("org.springframework..")
            .or().resideInAnyPackage("jakarta..")
            .because("領域只應依賴自身、基礎設施或框架類別")
            .check(importedClasses);
    }
}
```

## 📐 分層架構測試

### LayeredArchitectureTest.java
```java
package com.fakestore.architecture;

import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import org.junit.jupiter.api.DisplayName;

import static com.tngtech.archunit.library.Architectures.layeredArchitecture;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.*;

/**
 * 分層架構測試
 * 確保遵循 Clean Architecture 原則
 */
@AnalyzeClasses(packages = "com.fakestore")
@DisplayName("分層架構測試")
class LayeredArchitectureTest extends ArchitectureBaseTest {
    
    @ArchTest
    @DisplayName("分層架構規則")
    static final ArchRule layered_architecture_is_respected =
        layeredArchitecture()
            .consideringAllDependencies()
            .layer("Controllers").definedBy("..controller..")
            .layer("Services").definedBy("..service..")
            .layer("Repositories").definedBy("..repository..")
            .layer("Domain").definedBy("..domain..")
            .layer("Config").definedBy("..config..")
            
            .whereLayer("Controllers").mayNotBeAccessedByAnyLayer()
            .whereLayer("Services").mayOnlyBeAccessedByLayers("Controllers")
            .whereLayer("Repositories").mayOnlyBeAccessedByLayers("Services")
            .whereLayer("Domain").mayOnlyBeAccessedByLayers("Services", "Repositories")
            .whereLayer("Config").mayOnlyBeAccessedByLayers("Controllers", "Services");
    
    @ArchTest
    @DisplayName("Repository 層不應依賴 Controller 層")
    static final ArchRule repositories_should_not_depend_on_controllers =
        noClasses()
            .that().resideInAPackage("..repository..")
            .should().dependOnClassesThat()
            .resideInAPackage("..controller..")
            .because("Repository 層應該是最底層，不依賴上層");
    
    @ArchTest
    @DisplayName("Domain 層不應依賴基礎設施層")
    static final ArchRule domain_should_not_depend_on_infrastructure =
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat()
            .resideInAPackage("..repository..")
            .orShould().dependOnClassesThat()
            .resideInAPackage("..controller..")
            .because("領域層應保持純淨，不依賴基礎設施實作");
}
```

## 🏷️ 命名慣例測試

### NamingConventionTest.java
```java
package com.fakestore.architecture;

import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import org.springframework.stereotype.Controller;
import org.springframework.stereotype.Repository;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.RestController;
import org.junit.jupiter.api.DisplayName;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.*;

/**
 * 命名慣例測試
 * 確保類別命名符合專案規範
 */
@AnalyzeClasses(packages = "com.fakestore")
@DisplayName("命名慣例測試")
class NamingConventionTest extends ArchitectureBaseTest {
    
    @ArchTest
    @DisplayName("Controller 類應以 Controller 結尾")
    static final ArchRule controllers_should_be_suffixed =
        classes()
            .that().areAnnotatedWith(RestController.class)
            .or().areAnnotatedWith(Controller.class)
            .should().haveSimpleNameEndingWith("Controller")
            .because("Controller 類應該有清楚的命名模式");
    
    @ArchTest
    @DisplayName("Service 類應以 Service 結尾")
    static final ArchRule services_should_be_suffixed =
        classes()
            .that().areAnnotatedWith(Service.class)
            .and().resideInAPackage("..service..")
            .should().haveSimpleNameEndingWith("Service")
            .orShould().haveSimpleNameEndingWith("ServiceImpl")
            .because("Service 類應該有清楚的命名模式");
    
    @ArchTest
    @DisplayName("Repository 類應以 Repository 結尾")
    static final ArchRule repositories_should_be_suffixed =
        classes()
            .that().areAnnotatedWith(Repository.class)
            .or().that().resideInAPackage("..repository..")
            .should().haveSimpleNameEndingWith("Repository")
            .because("Repository 類應該有清楚的命名模式");
    
    @ArchTest
    @DisplayName("DTO 類應以 Dto, Request 或 Response 結尾")
    static final ArchRule dtos_should_be_suffixed =
        classes()
            .that().resideInAPackage("..dto..")
            .should().haveSimpleNameEndingWith("Dto")
            .orShould().haveSimpleNameEndingWith("Request") 
            .orShould().haveSimpleNameEndingWith("Response")
            .because("DTO 類應該有清楚的命名模式");
    
    @ArchTest
    @DisplayName("領域實體應避免使用技術相關後綴")
    static final ArchRule domain_entities_should_not_have_technical_suffixes =
        classes()
            .that().resideInAPackage("..domain..")
            .should().notHaveSimpleNameEndingWith("Entity")
            .andShould().notHaveSimpleNameEndingWith("Model")
            .andShould().notHaveSimpleNameEndingWith("Data")
            .because("領域實體應使用業務語言命名");
}
```

## 🔒 安全架構測試

### SecurityArchitectureTest.java
```java
package com.fakestore.architecture;

import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import com.fasterxml.jackson.annotation.JsonIgnore;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.junit.jupiter.api.DisplayName;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.*;

/**
 * 安全架構測試
 * 確保安全相關的架構規則
 */
@AnalyzeClasses(packages = "com.fakestore") 
@DisplayName("安全架構測試")
class SecurityArchitectureTest extends ArchitectureBaseTest {
    
    @ArchTest
    @DisplayName("敏感欄位應被排除序列化")
    static final ArchRule sensitive_fields_should_not_be_serialized =
        fields()
            .that().haveName("password")
            .or().haveNameMatching(".*[Pp]assword.*")
            .or().haveNameMatching(".*[Ss]ecret.*")
            .or().haveNameMatching(".*[Tt]oken.*")
            .should().beAnnotatedWith(JsonIgnore.class)
            .because("敏感資料不應出現在 JSON 回應中");
    
    @ArchTest
    @DisplayName("修改操作的端點應有安全註解")
    static final ArchRule modifying_endpoints_should_be_secured =
        methods()
            .that().areAnnotatedWith(PostMapping.class)
            .or().areAnnotatedWith(PutMapping.class)
            .or().areAnnotatedWith(PatchMapping.class)
            .or().areAnnotatedWith(DeleteMapping.class)
            .and().areDeclaredInClassesThat().areAnnotatedWith(RestController.class)
            .should().beAnnotatedWith(PreAuthorize.class)
            .because("修改操作需要適當的權限控制");
    
    @ArchTest
    @DisplayName("管理相關類別應在 admin 套件中")
    static final ArchRule admin_classes_should_be_in_admin_package =
        classes()
            .that().haveSimpleNameContaining("Admin")
            .should().resideInAPackage("..admin..")
            .because("管理功能應集中在 admin 套件中");
    
    @ArchTest
    @DisplayName("OAuth 相關類別不應被業務邏輯直接使用")
    static final ArchRule oauth_classes_should_not_be_used_directly =
        noClasses()
            .that().resideInAPackage("..product..")
            .or().resideInAPackage("..cart..")
            .or().resideInAPackage("..order..")
            .should().accessClassesThat()
            .resideInAPackage("..oauth..")
            .because("OAuth 認證應透過安全層統一處理");
}
```

## 🎨 DDD 架構測試

### DddArchitectureTest.java
```java
package com.fakestore.architecture;

import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import org.springframework.data.annotation.Id;
import jakarta.persistence.Entity;
import org.junit.jupiter.api.DisplayName;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.*;

/**
 * DDD 架構測試
 * 確保符合領域驅動設計原則
 */
@AnalyzeClasses(packages = "com.fakestore")
@DisplayName("DDD 架構測試")
class DddArchitectureTest extends ArchitectureBaseTest {
    
    @ArchTest
    @DisplayName("聚合根應該是 public 且不是 abstract")
    static final ArchRule aggregate_roots_should_be_properly_implemented =
        classes()
            .that().haveSimpleNameEndingWith("AggregateRoot")
            .or().areAnnotatedWith(AggregateRoot.class) // 假設有此註解
            .should().bePublic()
            .andShould().notBeAbstract()
            .because("聚合根需要被外部訪問且應該是具體實作");
    
    @ArchTest
    @DisplayName("實體應該有 equals 和 hashCode 方法")
    static final ArchRule entities_should_have_equals_and_hashcode =
        classes()
            .that().areAnnotatedWith(Entity.class)
            .should().haveMethod("equals", Object.class)
            .andShould().haveMethod("hashCode")
            .because("實體需要正確的相等性比較");
    
    @ArchTest
    @DisplayName("值物件應該是 immutable")
    static final ArchRule value_objects_should_be_immutable =
        classes()
            .that().haveSimpleNameEndingWith("ValueObject")
            .or().resideInAPackage("..valueobject..")
            .should().haveOnlyFinalFields()
            .because("值物件應該是不可變的");
    
    @ArchTest
    @DisplayName("領域服務應該是無狀態的")
    static final ArchRule domain_services_should_be_stateless =
        classes()
            .that().haveSimpleNameEndingWith("DomainService")
            .or().resideInAPackage("..domainservice..")
            .should().haveOnlyStaticMethods()
            .orShould().haveOnlyFinalFields()
            .because("領域服務應該是無狀態的");
    
    @ArchTest
    @DisplayName("Repository 介面應該在 domain 套件中")
    static final ArchRule repository_interfaces_should_be_in_domain =
        classes()
            .that().haveSimpleNameEndingWith("Repository")
            .and().areInterfaces()
            .should().resideInAPackage("..domain..")
            .because("Repository 介面屬於領域層");
}
```

## 🚀 CI/CD 整合

### GitHub Actions 工作流程
```yaml
# .github/workflows/architecture-test.yml
name: 架構測試

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  architecture-test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up JDK 21
      uses: actions/setup-java@v4
      with:
        java-version: '21'
        distribution: 'temurin'
        
    - name: Cache Gradle packages
      uses: actions/cache@v3
      with:
        path: |
          ~/.gradle/caches
          ~/.gradle/wrapper
        key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
        restore-keys: |
          ${{ runner.os }}-gradle-
    
    - name: 運行架構測試
      run: ./gradlew test --tests "*Architecture*Test" --info
      
    - name: 生成測試報告
      if: always()
      run: ./gradlew jacocoTestReport
      
    - name: 上傳測試結果
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: architecture-test-results
        path: |
          build/reports/tests/
          build/reports/jacoco/
```

## 📊 測試報告範例

### 架構違規報告
```
Architecture Violation [Priority: MEDIUM] - Rule 'no classes that reside in a package '..product..' should depend on classes that reside in a package '..cart..'' was violated (1 times):
Class <com.fakestore.product.service.ProductService> depends on class <com.fakestore.cart.CartItem> in (ProductService.java:15)

Suggestion: 考慮使用領域事件或共享內核來解決此依賴問題
```

### 成功測試範例輸出
```
✅ 領域邊界架構測試
  ✅ 產品領域不應依賴購物車領域
  ✅ 購物車領域不應依賴訂單領域
  ✅ 使用者領域不應依賴業務領域

✅ 分層架構測試  
  ✅ 分層架構規則
  ✅ Repository 層不應依賴 Controller 層

✅ 命名慣例測試
  ✅ Controller 類應以 Controller 結尾
  ✅ Service 類應以 Service 結尾
```

## 💡 最佳實踐建議

### 1. 漸進式引入
```java
// 先從簡單規則開始
@ArchTest
static final ArchRule classes_should_not_use_field_injection =
    noFields()
        .should().beAnnotatedWith(Autowired.class)
        .because("應使用建構子注入而非欄位注入");
```

### 2. 適度使用
```java
// 避免過度約束，保持開發靈活性
@ArchTest
static final ArchRule reasonable_rule_example =
    classes()
        .that().resideInAPackage("..controller..")
        .should().beAnnotatedWith(RestController.class)
        .orShould().beAnnotatedWith(Controller.class)
        .because("控制器應該有明確的角色註解");
```

### 3. 清晰的錯誤訊息
```java
@ArchTest
static final ArchRule rule_with_good_description =
    noClasses()
        .that().resideInAPackage("..domain..")
        .should().dependOnClassesThat()
        .resideInAPackage("..infrastructure..")
        .because("領域層不應該依賴基礎設施層。" +
               "建議：使用介面反轉依賴，在領域層定義介面，" +
               "在基礎設施層實作介面");
```

這個 ArchUnit 實作範例展示了如何在 Fake Store API 專案中具體應用架構測試，確保程式碼符合 DDD 原則和分層架構設計。

---

*最後更新: 2025-08-23*