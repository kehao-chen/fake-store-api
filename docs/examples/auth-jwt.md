# JWT 認證實作範例

本文件提供 JWT 認證機制的完整實作範例。

## 1. JWT 配置

### Security Configuration

```java
package com.fakestore.config;

import com.fakestore.security.JwtAuthenticationFilter;
import com.fakestore.security.JwtAuthenticationManager;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.annotation.method.configuration.EnableReactiveMethodSecurity;
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity;
import org.springframework.security.config.web.server.SecurityWebFiltersOrder;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.server.SecurityWebFilterChain;
import org.springframework.security.web.server.authentication.AuthenticationWebFilter;
import org.springframework.security.web.server.context.NoOpServerSecurityContextRepository;
import reactor.core.publisher.Mono;

@Configuration
@EnableWebFluxSecurity
@EnableReactiveMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {
    
    private final JwtAuthenticationManager authenticationManager;
    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    
    @Bean
    public SecurityWebFilterChain springSecurityFilterChain(ServerHttpSecurity http) {
        return http
            .csrf().disable()
            .formLogin().disable()
            .httpBasic().disable()
            .authenticationManager(authenticationManager)
            .securityContextRepository(NoOpServerSecurityContextRepository.getInstance())
            .exceptionHandling()
                .authenticationEntryPoint((exchange, ex) -> {
                    exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
                    return exchange.getResponse().setComplete();
                })
                .accessDeniedHandler((exchange, denied) -> {
                    exchange.getResponse().setStatusCode(HttpStatus.FORBIDDEN);
                    return exchange.getResponse().setComplete();
                })
            .and()
            .authorizeExchange()
                // 公開端點
                .pathMatchers(HttpMethod.GET, "/v1/products/**").permitAll()
                .pathMatchers(HttpMethod.GET, "/v1/categories/**").permitAll()
                .pathMatchers("/v1/auth/**").permitAll()
                .pathMatchers("/actuator/health").permitAll()
                .pathMatchers("/swagger-ui/**", "/v3/api-docs/**").permitAll()
                // 需要認證的端點
                .pathMatchers("/v1/users/me/**").authenticated()
                .pathMatchers("/v1/orders/**").authenticated()
                // 管理員端點
                .pathMatchers(HttpMethod.POST, "/v1/products/**").hasRole("ADMIN")
                .pathMatchers(HttpMethod.PATCH, "/v1/products/**").hasRole("ADMIN")
                .pathMatchers(HttpMethod.DELETE, "/v1/products/**").hasRole("ADMIN")
                .pathMatchers("/v1/admin/**").hasRole("ADMIN")
                // 其他都需要認證
                .anyExchange().authenticated()
            .and()
            .addFilterAt(jwtAuthenticationFilter, SecurityWebFiltersOrder.AUTHENTICATION)
            .build();
    }
    
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }
}
```

## 2. JWT Service

```java
package com.fakestore.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
public class JwtService {
    
    private final PrivateKey privateKey;
    private final PublicKey publicKey;
    private final long accessTokenExpiration;
    private final long refreshTokenExpiration;
    private final String issuer;
    private final String keyId;
    
    public JwtService(
            @Value("${jwt.private-key}") Resource privateKeyResource,
            @Value("${jwt.public-key}") Resource publicKeyResource,
            @Value("${jwt.access-token-expiration:900}") long accessTokenExpiration,
            @Value("${jwt.refresh-token-expiration:604800}") long refreshTokenExpiration,
            @Value("${jwt.issuer:fake-store-api}") String issuer,
            @Value("${jwt.key-id:fake-store-key-1}") String keyId) throws Exception {
        
        this.privateKey = loadPrivateKey(privateKeyResource);
        this.publicKey = loadPublicKey(publicKeyResource);
        this.accessTokenExpiration = accessTokenExpiration;
        this.refreshTokenExpiration = refreshTokenExpiration;
        this.issuer = issuer;
        this.keyId = keyId;
    }
    
    private PrivateKey loadPrivateKey(Resource resource) throws Exception {
        byte[] keyBytes = resource.getInputStream().readAllBytes();
        String privateKeyPEM = new String(keyBytes)
            .replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .replaceAll("\\s", "");
        
        byte[] decoded = Base64.getDecoder().decode(privateKeyPEM);
        PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(decoded);
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        return keyFactory.generatePrivate(keySpec);
    }
    
    private PublicKey loadPublicKey(Resource resource) throws Exception {
        byte[] keyBytes = resource.getInputStream().readAllBytes();
        String publicKeyPEM = new String(keyBytes)
            .replace("-----BEGIN PUBLIC KEY-----", "")
            .replace("-----END PUBLIC KEY-----", "")
            .replaceAll("\\s", "");
        
        byte[] decoded = Base64.getDecoder().decode(publicKeyPEM);
        X509EncodedKeySpec keySpec = new X509EncodedKeySpec(decoded);
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        return keyFactory.generatePublic(keySpec);
    }
    
    // 產生 Access Token
    public String generateAccessToken(String userId, String email, Set<String> roles) {
        Instant now = Instant.now();
        Instant expiry = now.plus(accessTokenExpiration, ChronoUnit.MINUTES);
        
        return Jwts.builder()
            .setId(UUID.randomUUID().toString())
            .setIssuer(issuer)
            .setSubject(userId)
            .setAudience("fake-store-api")
            .setIssuedAt(Date.from(now))
            .setExpiration(Date.from(expiry))
            .claim("email", email)
            .claim("roles", roles)
            .claim("type", "access")
            .setHeaderParam("kid", keyId)
            .signWith(privateKey, SignatureAlgorithm.RS256)
            .compact();
    }
    
    // 產生 Refresh Token
    public String generateRefreshToken(String userId) {
        Instant now = Instant.now();
        Instant expiry = now.plus(refreshTokenExpiration, ChronoUnit.MINUTES);
        
        return Jwts.builder()
            .setId(UUID.randomUUID().toString())
            .setIssuer(issuer)
            .setSubject(userId)
            .setIssuedAt(Date.from(now))
            .setExpiration(Date.from(expiry))
            .claim("type", "refresh")
            .setHeaderParam("kid", keyId)
            .signWith(privateKey, SignatureAlgorithm.RS256)
            .compact();
    }
    
    // 驗證 Token
    public Claims validateToken(String token) {
        try {
            return Jwts.parserBuilder()
                .setSigningKey(publicKey)
                .requireIssuer(issuer)
                .build()
                .parseClaimsJws(token)
                .getBody();
        } catch (ExpiredJwtException e) {
            log.warn("JWT Token 已過期: {}", e.getMessage());
            throw new TokenExpiredException("JWT Token 已過期", e);
        } catch (UnsupportedJwtException e) {
            log.warn("不支援的 JWT Token: {}", e.getMessage());
            throw new InvalidTokenException("不支援的 JWT Token", e);
        } catch (MalformedJwtException e) {
            log.warn("JWT Token 格式錯誤: {}", e.getMessage());
            throw new InvalidTokenException("JWT Token 格式錯誤", e);
        } catch (SignatureException e) {
            log.warn("JWT 簽名驗證失敗: {}", e.getMessage());
            throw new InvalidTokenException("JWT 簽名驗證失敗", e);
        } catch (IllegalArgumentException e) {
            log.warn("JWT Token 為空: {}", e.getMessage());
            throw new InvalidTokenException("JWT Token 為空", e);
        } catch (JwtException e) {
            log.warn("JWT Token 驗證失敗: {}", e.getMessage());
            throw new InvalidTokenException("JWT Token 驗證失敗", e);
        }
    }
    
    // 從 Token 中提取使用者資訊
    public UserPrincipal getUserFromToken(String token) {
        Claims claims = validateToken(token);
        
        String userId = claims.getSubject();
        String email = claims.get("email", String.class);
        List<String> roles = claims.get("roles", List.class);
        
        return UserPrincipal.builder()
            .userId(userId)
            .email(email)
            .roles(new HashSet<>(roles))
            .build();
    }
    
    // 重新整理 Token
    public TokenPair refreshToken(String refreshToken) {
        Claims claims = validateToken(refreshToken);
        
        // 驗證是否為 Refresh Token
        String tokenType = claims.get("type", String.class);
        if (!"refresh".equals(tokenType)) {
            throw new InvalidTokenException("不是有效的 Refresh Token");
        }
        
        String userId = claims.getSubject();
        
        // 這裡應該從資料庫重新載入使用者資訊
        // 為了範例簡化，直接使用 userId
        String newAccessToken = generateAccessToken(userId, "user@example.com", Set.of("ROLE_USER"));
        String newRefreshToken = generateRefreshToken(userId);
        
        return TokenPair.builder()
            .accessToken(newAccessToken)
            .refreshToken(newRefreshToken)
            .expiresIn(accessTokenExpiration * 60) // 轉換為秒
            .build();
    }
    
    // 撤銷 Token (需要配合 Valkey 實作黑名單)
    public void revokeToken(String token) {
        Claims claims = validateToken(token);
        String jti = claims.getId();
        Instant expiry = claims.getExpiration().toInstant();
        
        // 將 Token ID 加入黑名單，直到過期
        // valkeyTemplate.opsForValue().set("revoked:" + jti, true, Duration.between(Instant.now(), expiry));
        log.info("Token 已撤銷: {}", jti);
    }
}
```

## 3. Authentication Filter

```java
package com.fakestore.security;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.ReactiveSecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.server.ServerWebExchange;
import org.springframework.web.server.WebFilter;
import org.springframework.web.server.WebFilterChain;
import reactor.core.publisher.Mono;

import java.util.stream.Collectors;

@Slf4j
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter implements WebFilter {
    
    private static final String BEARER_PREFIX = "Bearer ";
    private final JwtService jwtService;
    
    @Override
    public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
        String token = extractToken(exchange.getRequest());
        
        if (StringUtils.hasText(token)) {
            try {
                UserPrincipal userPrincipal = jwtService.getUserFromToken(token);
                Authentication authentication = createAuthentication(userPrincipal);
                
                return chain.filter(exchange)
                    .contextWrite(ReactiveSecurityContextHolder.withAuthentication(authentication));
            } catch (Exception e) {
                log.debug("Token 驗證失敗: {}", e.getMessage());
            }
        }
        
        return chain.filter(exchange);
    }
    
    private String extractToken(ServerHttpRequest request) {
        String bearerToken = request.getHeaders().getFirst(HttpHeaders.AUTHORIZATION);
        
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith(BEARER_PREFIX)) {
            return bearerToken.substring(BEARER_PREFIX.length());
        }
        
        return null;
    }
    
    private Authentication createAuthentication(UserPrincipal userPrincipal) {
        var authorities = userPrincipal.getRoles().stream()
            .map(SimpleGrantedAuthority::new)
            .collect(Collectors.toList());
        
        return new UsernamePasswordAuthenticationToken(
            userPrincipal,
            null,
            authorities
        );
    }
}
```

## 4. Authentication Controller

```java
package com.fakestore.controller;

import com.fakestore.dto.request.LoginRequest;
import com.fakestore.dto.request.RegisterRequest;
import com.fakestore.dto.request.RefreshTokenRequest;
import com.fakestore.dto.response.AuthResponse;
import com.fakestore.dto.response.UserResponse;
import com.fakestore.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Mono;

import javax.validation.Valid;

@Slf4j
@RestController
@RequestMapping("/v1/auth")
@RequiredArgsConstructor
@Validated
@Tag(name = "Authentication", description = "認證相關 API")
public class AuthController {
    
    private final AuthService authService;
    
    @PostMapping("/register")
    @Operation(summary = "使用者註冊", description = "建立新的使用者帳號")
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<ResponseEntity<UserResponse>> register(
            @Valid @RequestBody RegisterRequest request) {
        
        log.info("使用者註冊 - email: {}", request.getEmail());
        
        return authService.register(request)
            .map(user -> ResponseEntity
                .status(HttpStatus.CREATED)
                .body(user))
            .doOnSuccess(response -> 
                log.info("註冊成功: {}", response.getBody().getId())
            )
            .doOnError(error -> 
                log.error("註冊失敗: {}", error.getMessage())
            );
    }
    
    @PostMapping("/login")
    @Operation(summary = "使用者登入", description = "使用帳號密碼登入")
    public Mono<ResponseEntity<AuthResponse>> login(
            @Valid @RequestBody LoginRequest request) {
        
        log.info("使用者登入 - email: {}", request.getEmail());
        
        return authService.login(request)
            .map(ResponseEntity::ok)
            .doOnSuccess(response -> 
                log.info("登入成功: {}", request.getEmail())
            )
            .doOnError(error -> 
                log.warn("登入失敗 - email: {}, 原因: {}", request.getEmail(), error.getMessage())
            );
    }
    
    @PostMapping("/refresh")
    @Operation(summary = "重新整理 Token", description = "使用 Refresh Token 獲取新的 Access Token")
    public Mono<ResponseEntity<AuthResponse>> refreshToken(
            @Valid @RequestBody RefreshTokenRequest request) {
        
        log.info("重新整理 Token");
        
        return authService.refreshToken(request.getRefreshToken())
            .map(ResponseEntity::ok)
            .doOnSuccess(response -> 
                log.info("Token 重新整理成功")
            );
    }
    
    @PostMapping("/logout")
    @Operation(summary = "登出", description = "撤銷當前的 Token")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<ResponseEntity<Void>> logout(
            @RequestHeader("Authorization") String authorization) {
        
        String token = authorization.substring(7); // 移除 "Bearer " 前綴
        log.info("使用者登出");
        
        return authService.logout(token)
            .then(Mono.just(ResponseEntity.noContent().<Void>build()))
            .doOnSuccess(response -> 
                log.info("登出成功")
            );
    }
}
```

## 5. Authentication Service

```java
package com.fakestore.service;

import com.fakestore.domain.user.User;
import com.fakestore.dto.request.LoginRequest;
import com.fakestore.dto.request.RegisterRequest;
import com.fakestore.dto.response.AuthResponse;
import com.fakestore.dto.response.UserResponse;
import com.fakestore.exception.EmailAlreadyExistsException;
import com.fakestore.exception.InvalidCredentialsException;
import com.fakestore.mapper.UserMapper;
import com.fakestore.repository.UserRepository;
import com.fakestore.security.JwtService;
import com.fakestore.security.TokenPair;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import reactor.core.publisher.Mono;

import java.util.Set;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {
    
    private final UserRepository userRepository;
    private final UserMapper userMapper;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;
    private final CacheService cacheService;
    
    @Transactional
    public Mono<UserResponse> register(RegisterRequest request) {
        // 檢查 Email 是否已存在
        return userRepository.existsByEmail(request.getEmail())
            .flatMap(exists -> {
                if (exists) {
                    return Mono.error(new EmailAlreadyExistsException(request.getEmail()));
                }
                
                // 建立新使用者
                User user = User.builder()
                    .id("user_" + UUID.randomUUID().toString().substring(0, 8))
                    .email(request.getEmail())
                    .username(request.getUsername())
                    .passwordHash(passwordEncoder.encode(request.getPassword()))
                    .firstName(request.getFirstName())
                    .lastName(request.getLastName())
                    .roles(Set.of("ROLE_USER"))
                    .isActive(true)
                    .isEmailVerified(false)
                    .build();
                
                return userRepository.save(user);
            })
            .map(userMapper::toResponse)
            .doOnSuccess(user -> {
                log.info("新使用者註冊成功: {}", user.getId());
                // 發送驗證郵件
                // emailService.sendVerificationEmail(user.getEmail());
            });
    }
    
    public Mono<AuthResponse> login(LoginRequest request) {
        return userRepository.findByEmail(request.getEmail())
            .switchIfEmpty(Mono.error(new InvalidCredentialsException()))
            .filter(user -> passwordEncoder.matches(request.getPassword(), user.getPasswordHash()))
            .switchIfEmpty(Mono.error(new InvalidCredentialsException()))
            .flatMap(user -> {
                if (!user.getIsActive()) {
                    return Mono.error(new AccountDisabledException("帳號已停用"));
                }
                
                // 產生 Token
                String accessToken = jwtService.generateAccessToken(
                    user.getId(),
                    user.getEmail(),
                    user.getRoles()
                );
                String refreshToken = jwtService.generateRefreshToken(user.getId());
                
                // 更新最後登入時間
                user.updateLastLogin();
                
                return userRepository.save(user)
                    .then(Mono.just(AuthResponse.builder()
                        .accessToken(accessToken)
                        .refreshToken(refreshToken)
                        .tokenType("Bearer")
                        .expiresIn(900) // 15 分鐘
                        .user(userMapper.toResponse(user))
                        .build()));
            })
            .doOnSuccess(response -> 
                log.info("使用者登入成功: {}", response.getUser().getId())
            );
    }
    
    public Mono<AuthResponse> refreshToken(String refreshToken) {
        TokenPair tokenPair = jwtService.refreshToken(refreshToken);
        
        String userId = jwtService.validateToken(refreshToken).getSubject();
        
        return userRepository.findById(userId)
            .map(user -> AuthResponse.builder()
                .accessToken(tokenPair.getAccessToken())
                .refreshToken(tokenPair.getRefreshToken())
                .tokenType("Bearer")
                .expiresIn(tokenPair.getExpiresIn())
                .user(userMapper.toResponse(user))
                .build())
            .doOnSuccess(response -> 
                log.info("Token 重新整理成功: {}", response.getUser().getId())
            );
    }
    
    public Mono<Void> logout(String token) {
        // 撤銷 Token
        jwtService.revokeToken(token);
        
        // 清除快取
        String userId = jwtService.validateToken(token).getSubject();
        return cacheService.evictUserCache(userId)
            .doOnSuccess(v -> 
                log.info("使用者登出成功: {}", userId)
            );
    }
}
```

## 6. JWK (JSON Web Key) 端點

```java
package com.fakestore.controller;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Mono;

import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import java.util.List;

@Slf4j
@RestController
@RequestMapping("/.well-known")
public class JwkController {
    
    private final String keyId;
    private final RSAPublicKey publicKey;
    
    public JwkController(
            @Value("${jwt.public-key}") Resource publicKeyResource,
            @Value("${jwt.key-id:fake-store-key-1}") String keyId) throws Exception {
        this.keyId = keyId;
        this.publicKey = loadRSAPublicKey(publicKeyResource);
    }
    
    private RSAPublicKey loadRSAPublicKey(Resource resource) throws Exception {
        byte[] keyBytes = resource.getInputStream().readAllBytes();
        String publicKeyPEM = new String(keyBytes)
            .replace("-----BEGIN PUBLIC KEY-----", "")
            .replace("-----END PUBLIC KEY-----", "")
            .replaceAll("\\s", "");
        
        byte[] decoded = Base64.getDecoder().decode(publicKeyPEM);
        X509EncodedKeySpec keySpec = new X509EncodedKeySpec(decoded);
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        return (RSAPublicKey) keyFactory.generatePublic(keySpec);
    }
    
    @GetMapping("/jwks.json")
    public Mono<ResponseEntity<JwkSet>> getJwks() {
        JwkKey jwkKey = new JwkKey(
            "RSA",  // kty
            "sig",  // use
            "RS256", // alg
            keyId,  // kid
            Base64.getUrlEncoder().withoutPadding().encodeToString(publicKey.getModulus().toByteArray()),
            Base64.getUrlEncoder().withoutPadding().encodeToString(publicKey.getPublicExponent().toByteArray())
        );
        
        JwkSet jwkSet = new JwkSet(List.of(jwkKey));
        
        return Mono.just(ResponseEntity.ok()
            .header("Cache-Control", "public, max-age=3600")
            .body(jwkSet));
    }
    
    @Data
    @AllArgsConstructor
    public static class JwkSet {
        private List<JwkKey> keys;
    }
    
    @Data
    @AllArgsConstructor  
    public static class JwkKey {
        @JsonProperty("kty")
        private String keyType;
        
        @JsonProperty("use")
        private String use;
        
        @JsonProperty("alg")
        private String algorithm;
        
        @JsonProperty("kid")
        private String keyId;
        
        @JsonProperty("n")
        private String modulus;
        
        @JsonProperty("e")
        private String exponent;
    }
}
}
```

## 7. RSA 金鑰配置與生成

### 7.1 生成 RSA 金鑰對

```bash
# 生成私鑰 (PKCS#8 format)
openssl genrsa -out private_key.pem 2048
openssl pkcs8 -topk8 -inform PEM -outform PEM -in private_key.pem -out private_key_pkcs8.pem -nocrypt

# 生成公鑰  
openssl rsa -in private_key.pem -pubout -out public_key.pem

# 檢查金鑰
openssl rsa -in private_key_pkcs8.pem -text -noout
openssl rsa -in public_key.pem -pubin -text -noout
```

### 7.2 Spring Boot 配置

```yaml
# application.yml
jwt:
  private-key: classpath:keys/private_key_pkcs8.pem
  public-key: classpath:keys/public_key.pem
  key-id: fake-store-key-1
  issuer: fake-store-api
  access-token-expiration: 900    # 秒 (15 分鐘)
  refresh-token-expiration: 604800 # 秒 (7天)
```

### 7.3 Security 配置更新

```java
// 更新 SecurityConfig 以允許 JWK 端點
.pathMatchers("/.well-known/jwks.json").permitAll()
```

## 8. OAuth 2.0 整合

```java
package com.fakestore.security.oauth;

import com.fakestore.domain.user.User;
import com.fakestore.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.oauth2.client.userinfo.DefaultReactiveOAuth2UserService;
import org.springframework.security.oauth2.client.userinfo.OAuth2UserRequest;
import org.springframework.security.oauth2.client.userinfo.ReactiveOAuth2UserService;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Mono;

import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class CustomOAuth2UserService implements ReactiveOAuth2UserService<OAuth2UserRequest, OAuth2User> {
    
    private final UserRepository userRepository;
    private final DefaultReactiveOAuth2UserService delegate = new DefaultReactiveOAuth2UserService();
    
    @Override
    public Mono<OAuth2User> loadUser(OAuth2UserRequest userRequest) throws OAuth2AuthenticationException {
        return delegate.loadUser(userRequest)
            .flatMap(oAuth2User -> processOAuth2User(userRequest, oAuth2User));
    }
    
    private Mono<OAuth2User> processOAuth2User(OAuth2UserRequest userRequest, OAuth2User oAuth2User) {
        String provider = userRequest.getClientRegistration().getRegistrationId();
        Map<String, Object> attributes = oAuth2User.getAttributes();
        
        String email = extractEmail(provider, attributes);
        String name = extractName(provider, attributes);
        String providerId = extractProviderId(provider, attributes);
        
        return userRepository.findByEmail(email)
            .switchIfEmpty(createNewUser(email, name, provider, providerId))
            .flatMap(user -> updateOAuthInfo(user, provider, providerId))
            .map(user -> new CustomOAuth2User(oAuth2User, user));
    }
    
    private Mono<User> createNewUser(String email, String name, String provider, String providerId) {
        User newUser = User.builder()
            .id("user_" + UUID.randomUUID().toString().substring(0, 8))
            .email(email)
            .username(email.split("@")[0])
            .firstName(name)
            .roles(Set.of("ROLE_USER"))
            .isActive(true)
            .isEmailVerified(true) // OAuth 使用者預設已驗證
            .oauthProvider(provider)
            .oauthProviderId(providerId)
            .build();
        
        log.info("建立新的 OAuth 使用者: {} via {}", email, provider);
        return userRepository.save(newUser);
    }
    
    private Mono<User> updateOAuthInfo(User user, String provider, String providerId) {
        user.setOauthProvider(provider);
        user.setOauthProviderId(providerId);
        user.updateLastLogin();
        
        return userRepository.save(user);
    }
    
    private String extractEmail(String provider, Map<String, Object> attributes) {
        switch (provider) {
            case "google":
                return (String) attributes.get("email");
            case "github":
                return (String) attributes.get("email");
            default:
                throw new OAuth2AuthenticationException("不支援的 OAuth 提供者: " + provider);
        }
    }
    
    private String extractName(String provider, Map<String, Object> attributes) {
        switch (provider) {
            case "google":
                return (String) attributes.get("name");
            case "github":
                return (String) attributes.get("name");
            default:
                return "OAuth User";
        }
    }
    
    private String extractProviderId(String provider, Map<String, Object> attributes) {
        switch (provider) {
            case "google":
                return (String) attributes.get("sub");
            case "github":
                return String.valueOf(attributes.get("id"));
            default:
                return UUID.randomUUID().toString();
        }
    }
}
```

---

最後更新：2025-08-20
