package com.ticketdesk.auth.controller;

import com.ticketdesk.auth.dto.LoginRequest;
import com.ticketdesk.auth.dto.RegisterRequest;
import com.ticketdesk.auth.entity.UserAccount;
import com.ticketdesk.auth.repository.UserRepository;
import com.ticketdesk.auth.util.JwtUtil;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    private final UserRepository userRepository;
    private final JwtUtil jwtUtil;

    public AuthController(UserRepository userRepository, JwtUtil jwtUtil) {
        this.userRepository = userRepository;
        this.jwtUtil = jwtUtil;
    }

    // ── POST /api/v1/auth/login ─────────────────────────────────────────────
    @PostMapping("/login")
    public ResponseEntity<Map<String, Object>> login(@Valid @RequestBody LoginRequest req) {
        Optional<UserAccount> opt = userRepository.findByEmail(req.getEmail());
        if (opt.isEmpty() || !opt.get().getPassword().equals(req.getPassword()) || !opt.get().isActive()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(error("Invalid email or password"));
        }
        UserAccount user = opt.get();
        String token = jwtUtil.generate(user.getId(), user.getEmail(), user.getName(), user.getRole().name());
        return ResponseEntity.ok(success("Login successful", buildUserMap(user, token)));
    }

    // ── POST /api/v1/auth/register  (USER only — public self-registration) ──
    @PostMapping("/register")
    public ResponseEntity<Map<String, Object>> register(@Valid @RequestBody RegisterRequest req) {
        // Only USER role allowed via public registration
        if (!"USER".equalsIgnoreCase(req.getRole())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(error("Only USER accounts can be self-registered. AGENT accounts must be created by an Admin."));
        }
        if (userRepository.existsByEmail(req.getEmail())) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(error("Email is already registered"));
        }
        UserAccount saved = userRepository.save(
                new UserAccount(req.getName(), req.getEmail(), req.getPassword(), UserAccount.Role.USER));
        String token = jwtUtil.generate(saved.getId(), saved.getEmail(), saved.getName(), saved.getRole().name());
        return ResponseEntity.status(HttpStatus.CREATED).body(success("Registration successful", buildUserMap(saved, token)));
    }

    // ── POST /api/v1/auth/agents  (ADMIN creates an AGENT account) ──────────
    @PostMapping("/agents")
    public ResponseEntity<Map<String, Object>> createAgent(@Valid @RequestBody RegisterRequest req,
                                                           @RequestHeader(value = "X-User-Role", defaultValue = "") String callerRole) {
        if (!"ADMIN".equalsIgnoreCase(callerRole)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(error("Only ADMIN can create AGENT accounts"));
        }
        if (userRepository.existsByEmail(req.getEmail())) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(error("Email is already registered"));
        }
        UserAccount saved = userRepository.save(
                new UserAccount(req.getName(), req.getEmail(), req.getPassword(), UserAccount.Role.AGENT));
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(success("Agent account created successfully", buildUserMap(saved, null)));
    }

    // ── GET /api/v1/auth/users  (ADMIN — list all users) ───────────────────
    @GetMapping("/users")
    public ResponseEntity<Map<String, Object>> listUsers() {
        List<Map<String, Object>> users = userRepository.findAll().stream()
                .map(u -> buildUserMap(u, null))
                .collect(Collectors.toList());
        return ResponseEntity.ok(success("Users retrieved", users));
    }

    // ── GET /api/v1/auth/agents  (ADMIN — list only agents) ────────────────
    @GetMapping("/agents")
    public ResponseEntity<Map<String, Object>> listAgents() {
        List<Map<String, Object>> agents = userRepository.findAll().stream()
                .filter(u -> u.getRole() == UserAccount.Role.AGENT && u.isActive())
                .map(u -> buildUserMap(u, null))
                .collect(Collectors.toList());
        return ResponseEntity.ok(success("Agents retrieved", agents));
    }

    // ── DELETE /api/v1/auth/users/{id}  (ADMIN — delete user/agent) ─────────
    @DeleteMapping("/users/{id}")
    public ResponseEntity<Map<String, Object>> deleteUser(@PathVariable Long id,
                                                          @RequestHeader(value = "X-User-Role", defaultValue = "") String callerRole) {
        if (!"ADMIN".equalsIgnoreCase(callerRole)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(error("Only ADMIN can delete accounts"));
        }
        Optional<UserAccount> opt = userRepository.findById(id);
        if (opt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(error("User not found"));
        }
        if (opt.get().getRole() == UserAccount.Role.ADMIN) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(error("Cannot delete the admin account"));
        }
        userRepository.deleteById(id);
        return ResponseEntity.ok(success("Account deleted successfully", null));
    }

    // ── Helpers ──────────────────────────────────────────────────────────────
    private Map<String, Object> buildUserMap(UserAccount u, String token) {
        Map<String, Object> m = new HashMap<>();
        m.put("id", u.getId());
        m.put("name", u.getName());
        m.put("email", u.getEmail());
        m.put("role", u.getRole().name());
        m.put("active", u.isActive());
        m.put("createdAt", u.getCreatedAt());
        if (token != null) m.put("token", token);
        return m;
    }

    private Map<String, Object> success(String msg, Object data) {
        Map<String, Object> r = new HashMap<>();
        r.put("success", true);
        r.put("message", msg);
        r.put("data", data);
        return r;
    }

    private Map<String, Object> error(String msg) {
        Map<String, Object> r = new HashMap<>();
        r.put("success", false);
        r.put("message", msg);
        return r;
    }
}
