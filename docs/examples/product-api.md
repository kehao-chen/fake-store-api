# 產品 API 實作範例

本文件提供產品管理功能的完整實作範例。

## 1. 領域模型 (Domain Model)

### Product Entity

```java
package com.fakestore.domain.product;

import lombok.Data;
import lombok.Builder;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.relational.core.mapping.Table;
import org.springframework.data.relational.core.mapping.Column;

import javax.validation.constraints.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table("products")
public class Product {
    
    @Id
    @Column("id")
    private String id;
    
    @NotBlank(message = "產品名稱不能為空")
    @Size(min = 1, max = 200, message = "產品名稱長度必須在 1-200 字元之間")
    @Column("name")
    private String name;
    
    @Size(max = 2000, message = "產品描述不能超過 2000 字元")
    @Column("description")
    private String description;
    
    @NotNull(message = "價格不能為空")
    @DecimalMin(value = "0.0", inclusive = false, message = "價格必須大於 0")
    @Digits(integer = 10, fraction = 2, message = "價格格式錯誤")
    @Column("price")
    private BigDecimal price;
    
    @NotBlank(message = "分類 ID 不能為空")
    @Pattern(regexp = "^cat_[a-zA-Z0-9]+$", message = "分類 ID 格式錯誤")
    @Column("category_id")
    private String categoryId;
    
    @Column("image_url")
    private String imageUrl;
    
    @Column("sku")
    private String sku;
    
    @Min(value = 0, message = "庫存數量不能為負數")
    @Column("stock_quantity")
    private Integer stockQuantity;
    
    @Column("is_active")
    @Builder.Default
    private Boolean isActive = true;
    
    @CreatedDate
    @Column("created_at")
    private Instant createdAt;
    
    @LastModifiedDate
    @Column("updated_at")
    private Instant updatedAt;
    
    // 領域方法
    public void updateStock(int quantity) {
        if (this.stockQuantity + quantity < 0) {
            throw new InsufficientStockException(
                String.format("庫存不足，當前庫存: %d, 請求數量: %d", 
                    this.stockQuantity, quantity)
            );
        }
        this.stockQuantity += quantity;
        this.updatedAt = Instant.now();
    }
    
    public void changePrice(BigDecimal newPrice) {
        if (newPrice == null || newPrice.compareTo(BigDecimal.ZERO) <= 0) {
            throw new InvalidPriceException("價格必須大於 0");
        }
        this.price = newPrice;
        this.updatedAt = Instant.now();
    }
    
    public void deactivate() {
        this.isActive = false;
        this.updatedAt = Instant.now();
    }
    
    public void activate() {
        this.isActive = true;
        this.updatedAt = Instant.now();
    }
    
    // 靜態工廠方法
    public static Product create(String name, BigDecimal price, String categoryId) {
        return Product.builder()
            .id("prod_" + UUID.randomUUID().toString().substring(0, 8))
            .name(name)
            .price(price)
            .categoryId(categoryId)
            .stockQuantity(0)
            .isActive(true)
            .build();
    }
}
```

## 2. REST Controller

```java
package com.fakestore.controller;

import com.fakestore.domain.product.Product;
import com.fakestore.dto.request.CreateProductRequest;
import com.fakestore.dto.request.UpdateProductRequest;
import com.fakestore.dto.response.ProductResponse;
import com.fakestore.dto.response.PagedResponse;
import com.fakestore.service.ProductService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import javax.validation.Valid;
import javax.validation.constraints.Max;
import javax.validation.constraints.Min;
import java.util.List;

@Slf4j
@RestController
@RequestMapping("/v1/products")
@RequiredArgsConstructor
@Validated
@Tag(name = "Products", description = "產品管理 API")
public class ProductController {
    
    private final ProductService productService;
    
    @GetMapping
    @Operation(
        summary = "列出產品",
        description = "獲取產品列表，支援分頁、篩選和排序"
    )
    @ApiResponse(
        responseCode = "200",
        description = "成功返回產品列表",
        content = @Content(schema = @Schema(implementation = PagedResponse.class))
    )
    public Mono<ResponseEntity<PagedResponse<ProductResponse>>> listProducts(
            @Parameter(description = "每頁結果數量")
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) Integer pageSize,
            
            @Parameter(description = "分頁令牌")
            @RequestParam(required = false) String pageToken,
            
            @Parameter(description = "篩選條件 (AIP-160 語法)")
            @RequestParam(required = false) String filter,
            
            @Parameter(description = "排序欄位和方向")
            @RequestParam(defaultValue = "created_at desc") String orderBy) {
        
        log.info("列出產品 - pageSize: {}, pageToken: {}, filter: {}, orderBy: {}", 
            pageSize, pageToken, filter, orderBy);
        
        return productService.listProducts(pageSize, pageToken, filter, orderBy)
            .map(response -> ResponseEntity.ok()
                .header("X-Total-Count", String.valueOf(response.getTotalSize()))
                .header("Cache-Control", "public, max-age=300")
                .body(response))
            .doOnSuccess(response -> 
                log.info("成功返回 {} 個產品", response.getBody().getItems().size())
            );
    }
    
    @GetMapping("/{id}")
    @Operation(
        summary = "獲取產品詳情",
        description = "根據 ID 獲取單一產品的詳細資訊"
    )
    public Mono<ResponseEntity<ProductResponse>> getProduct(
            @Parameter(description = "產品 ID", required = true)
            @PathVariable String id) {
        
        log.info("獲取產品詳情 - id: {}", id);
        
        return productService.getProduct(id)
            .map(product -> ResponseEntity.ok()
                .header("Cache-Control", "public, max-age=600")
                .body(product))
            .switchIfEmpty(Mono.just(ResponseEntity.notFound().build()))
            .doOnSuccess(response -> {
                if (response.getStatusCode().is2xxSuccessful()) {
                    log.info("成功獲取產品: {}", id);
                } else {
                    log.warn("產品不存在: {}", id);
                }
            });
    }
    
    @PostMapping
    @Operation(
        summary = "建立產品",
        description = "建立新產品（需要管理員權限）"
    )
    @SecurityRequirement(name = "bearerAuth")
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<ResponseEntity<ProductResponse>> createProduct(
            @Valid @RequestBody CreateProductRequest request) {
        
        log.info("建立產品 - name: {}, price: {}, category: {}", 
            request.getName(), request.getPrice(), request.getCategoryId());
        
        return productService.createProduct(request)
            .map(product -> ResponseEntity
                .status(HttpStatus.CREATED)
                .header("Location", "/v1/products/" + product.getId())
                .body(product))
            .doOnSuccess(response -> 
                log.info("成功建立產品: {}", response.getBody().getId())
            )
            .doOnError(error -> 
                log.error("建立產品失敗: {}", error.getMessage())
            );
    }
    
    @PutMapping("/{id}")
    @Operation(
        summary = "更新產品",
        description = "更新產品資訊（需要管理員權限）"
    )
    @SecurityRequirement(name = "bearerAuth")
    @PreAuthorize("hasRole('ADMIN')")
    public Mono<ResponseEntity<ProductResponse>> updateProduct(
            @PathVariable String id,
            @Valid @RequestBody UpdateProductRequest request) {
        
        log.info("更新產品 - id: {}", id);
        
        return productService.updateProduct(id, request)
            .map(ResponseEntity::ok)
            .switchIfEmpty(Mono.just(ResponseEntity.notFound().build()))
            .doOnSuccess(response -> {
                if (response.getStatusCode().is2xxSuccessful()) {
                    log.info("成功更新產品: {}", id);
                }
            });
    }
    
    @DeleteMapping("/{id}")
    @Operation(
        summary = "刪除產品",
        description = "軟刪除產品（需要管理員權限）"
    )
    @SecurityRequirement(name = "bearerAuth")
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<ResponseEntity<Void>> deleteProduct(@PathVariable String id) {
        
        log.info("刪除產品 - id: {}", id);
        
        return productService.deleteProduct(id)
            .then(Mono.just(ResponseEntity.noContent().<Void>build()))
            .switchIfEmpty(Mono.just(ResponseEntity.notFound().build()))
            .doOnSuccess(response -> {
                if (response.getStatusCode().is2xxSuccessful()) {
                    log.info("成功刪除產品: {}", id);
                }
            });
    }
    
    @PostMapping(":batchGet")
    @Operation(
        summary = "批量獲取產品",
        description = "根據 ID 列表批量獲取產品"
    )
    public Mono<ResponseEntity<List<ProductResponse>>> batchGetProducts(
            @RequestBody @Valid BatchGetRequest request) {
        
        log.info("批量獲取產品 - 數量: {}", request.getProductIds().size());
        
        return productService.batchGetProducts(request.getProductIds())
            .collectList()
            .map(ResponseEntity::ok)
            .doOnSuccess(response -> 
                log.info("成功返回 {} 個產品", response.getBody().size())
            );
    }
    
    @PostMapping(":search")
    @Operation(
        summary = "搜尋產品",
        description = "全文搜尋產品"
    )
    public Mono<ResponseEntity<PagedResponse<ProductResponse>>> searchProducts(
            @RequestBody @Valid SearchRequest request) {
        
        log.info("搜尋產品 - 關鍵字: {}", request.getQuery());
        
        return productService.searchProducts(request)
            .map(ResponseEntity::ok)
            .doOnSuccess(response -> 
                log.info("搜尋結果: {} 個產品", response.getBody().getTotalSize())
            );
    }
}
```

## 3. Service Layer

```java
package com.fakestore.service;

import com.fakestore.domain.product.Product;
import com.fakestore.dto.request.CreateProductRequest;
import com.fakestore.dto.request.UpdateProductRequest;
import com.fakestore.dto.response.ProductResponse;
import com.fakestore.dto.response.PagedResponse;
import com.fakestore.exception.ProductNotFoundException;
import com.fakestore.exception.DuplicateSkuException;
import com.fakestore.mapper.ProductMapper;
import com.fakestore.repository.ProductRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class ProductService {
    
    private final ProductRepository productRepository;
    private final ProductMapper productMapper;
    private final CacheService cacheService;
    private final EventPublisher eventPublisher;
    
    @Cacheable(value = "products", key = "#id")
    public Mono<ProductResponse> getProduct(String id) {
        return productRepository.findById(id)
            .map(productMapper::toResponse)
            .switchIfEmpty(Mono.error(new ProductNotFoundException(id)));
    }
    
    public Mono<PagedResponse<ProductResponse>> listProducts(
            Integer pageSize, String pageToken, String filter, String orderBy) {
        
        // 解析分頁和排序參數
        PageRequest pageRequest = buildPageRequest(pageSize, pageToken, orderBy);
        
        // 建構查詢條件
        Criteria criteria = buildCriteria(filter);
        
        return productRepository.findAllByCriteria(criteria, pageRequest)
            .map(productMapper::toResponse)
            .collectList()
            .zipWith(productRepository.countByCriteria(criteria))
            .map(tuple -> PagedResponse.<ProductResponse>builder()
                .items(tuple.getT1())
                .totalSize(tuple.getT2())
                .nextPageToken(generateNextPageToken(tuple.getT1(), pageSize))
                .build());
    }
    
    @Transactional
    @CacheEvict(value = "products", allEntries = true)
    public Mono<ProductResponse> createProduct(CreateProductRequest request) {
        // 檢查 SKU 是否重複
        return productRepository.existsBySku(request.getSku())
            .flatMap(exists -> {
                if (exists) {
                    return Mono.error(new DuplicateSkuException(request.getSku()));
                }
                
                Product product = Product.create(
                    request.getName(),
                    request.getPrice(),
                    request.getCategoryId()
                );
                
                product.setDescription(request.getDescription());
                product.setImageUrl(request.getImageUrl());
                product.setSku(request.getSku());
                product.setStockQuantity(request.getStockQuantity());
                
                return productRepository.save(product);
            })
            .doOnSuccess(product -> {
                // 發布產品建立事件
                eventPublisher.publishProductCreated(product);
            })
            .map(productMapper::toResponse);
    }
    
    @Transactional
    @CacheEvict(value = "products", key = "#id")
    public Mono<ProductResponse> updateProduct(String id, UpdateProductRequest request) {
        return productRepository.findById(id)
            .switchIfEmpty(Mono.error(new ProductNotFoundException(id)))
            .flatMap(product -> {
                // 更新產品屬性
                if (request.getName() != null) {
                    product.setName(request.getName());
                }
                if (request.getDescription() != null) {
                    product.setDescription(request.getDescription());
                }
                if (request.getPrice() != null) {
                    product.changePrice(request.getPrice());
                }
                if (request.getStockQuantity() != null) {
                    product.setStockQuantity(request.getStockQuantity());
                }
                
                return productRepository.save(product);
            })
            .doOnSuccess(product -> {
                // 發布產品更新事件
                eventPublisher.publishProductUpdated(product);
            })
            .map(productMapper::toResponse);
    }
    
    @Transactional
    @CacheEvict(value = "products", key = "#id")
    public Mono<Void> deleteProduct(String id) {
        return productRepository.findById(id)
            .switchIfEmpty(Mono.error(new ProductNotFoundException(id)))
            .flatMap(product -> {
                product.deactivate();
                return productRepository.save(product);
            })
            .doOnSuccess(product -> {
                // 發布產品刪除事件
                eventPublisher.publishProductDeleted(product);
            })
            .then();
    }
    
    public Flux<ProductResponse> batchGetProducts(List<String> productIds) {
        return productRepository.findAllById(productIds)
            .map(productMapper::toResponse);
    }
    
    // 輔助方法
    private PageRequest buildPageRequest(Integer pageSize, String pageToken, String orderBy) {
        // 實作分頁邏輯
        int page = pageToken != null ? decodePageToken(pageToken) : 0;
        Sort sort = parseOrderBy(orderBy);
        return PageRequest.of(page, pageSize, sort);
    }
    
    private Criteria buildCriteria(String filter) {
        // 實作篩選條件解析
        if (filter == null || filter.isEmpty()) {
            return Criteria.empty();
        }
        // 解析 AIP-160 語法
        return FilterParser.parse(filter);
    }
    
    private String generateNextPageToken(List<ProductResponse> items, Integer pageSize) {
        if (items.size() < pageSize) {
            return null;
        }
        // 產生下一頁令牌
        return encodePageToken(items.get(items.size() - 1).getId());
    }
}
```

## 4. Repository Layer

```java
package com.fakestore.repository;

import com.fakestore.domain.product.Product;
import org.springframework.data.domain.Pageable;
import org.springframework.data.r2dbc.repository.Query;
import org.springframework.data.r2dbc.repository.R2dbcRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.math.BigDecimal;
import java.util.List;

@Repository
public interface ProductRepository extends R2dbcRepository<Product, String> {
    
    // 基本查詢
    Flux<Product> findByIsActiveTrue(Pageable pageable);
    
    Flux<Product> findByCategoryId(String categoryId);
    
    Flux<Product> findByPriceBetween(BigDecimal minPrice, BigDecimal maxPrice);
    
    Mono<Boolean> existsBySku(String sku);
    
    // 自定義查詢
    @Query("""
        SELECT * FROM products p
        WHERE p.is_active = true
        AND (:categoryId IS NULL OR p.category_id = :categoryId)
        AND (:minPrice IS NULL OR p.price >= :minPrice)
        AND (:maxPrice IS NULL OR p.price <= :maxPrice)
        AND (:keyword IS NULL OR 
             p.name ILIKE '%' || :keyword || '%' OR 
             p.description ILIKE '%' || :keyword || '%')
        ORDER BY p.created_at DESC
        LIMIT :limit OFFSET :offset
        """)
    Flux<Product> searchProducts(
        @Param("categoryId") String categoryId,
        @Param("minPrice") BigDecimal minPrice,
        @Param("maxPrice") BigDecimal maxPrice,
        @Param("keyword") String keyword,
        @Param("limit") int limit,
        @Param("offset") int offset
    );
    
    @Query("""
        SELECT COUNT(*) FROM products p
        WHERE p.is_active = true
        AND (:categoryId IS NULL OR p.category_id = :categoryId)
        AND (:minPrice IS NULL OR p.price >= :minPrice)
        AND (:maxPrice IS NULL OR p.price <= :maxPrice)
        AND (:keyword IS NULL OR 
             p.name ILIKE '%' || :keyword || '%' OR 
             p.description ILIKE '%' || :keyword || '%')
        """)
    Mono<Long> countSearchResults(
        @Param("categoryId") String categoryId,
        @Param("minPrice") BigDecimal minPrice,
        @Param("maxPrice") BigDecimal maxPrice,
        @Param("keyword") String keyword
    );
    
    // 批量操作
    @Query("SELECT * FROM products WHERE id = ANY(:ids) AND is_active = true")
    Flux<Product> findAllByIdIn(@Param("ids") List<String> ids);
    
    // 庫存相關
    @Query("""
        UPDATE products 
        SET stock_quantity = stock_quantity + :quantity,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = :id 
        AND stock_quantity + :quantity >= 0
        RETURNING *
        """)
    Mono<Product> updateStock(@Param("id") String id, @Param("quantity") int quantity);
}
```

---

最後更新：2025-08-20