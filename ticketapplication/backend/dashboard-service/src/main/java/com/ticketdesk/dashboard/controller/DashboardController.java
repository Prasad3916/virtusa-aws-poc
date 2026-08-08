package com.ticketdesk.dashboard.controller;

import com.ticketdesk.dashboard.dto.ApiResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/dashboard")
@CrossOrigin(origins = "*")
public class DashboardController {

    private final JdbcTemplate jdbc;

    public DashboardController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * GET /api/v1/dashboard/summary
     * Returns total ticket count, counts by status, priority and category.
     */
    @GetMapping("/summary")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSummary() {
        Map<String, Object> summary = new HashMap<>();

        try {
            Long total = jdbc.queryForObject("SELECT COUNT(*) FROM tickets", Long.class);
            summary.put("totalTickets", total == null ? 0 : total);
            summary.put("statusCounts", countByColumn("status"));
            summary.put("priorityCounts", countByColumn("priority"));
            summary.put("categoryCounts", countByColumn("category"));
        } catch (Exception e) {
            // Return safe default if table doesn't exist yet or query fails
            summary.put("totalTickets", 0);
            summary.put("statusCounts", new HashMap<String, Long>());
            summary.put("priorityCounts", new HashMap<String, Long>());
            summary.put("categoryCounts", new HashMap<String, Long>());
        }

        return ResponseEntity.ok(ApiResponse.success("Dashboard summary retrieved", summary));
    }

    /**
     * GET /api/v1/dashboard/health
     */
    @GetMapping("/health")
    public ResponseEntity<ApiResponse<Map<String, String>>> health() {
        return ResponseEntity.ok(ApiResponse.success("OK", Map.of("status", "UP")));
    }

    // ── Helper ────────────────────────────────────────────────────────────────
    private Map<String, Long> countByColumn(String column) {
        Map<String, Long> result = new HashMap<>();
        try {
            String sql = "SELECT " + column + ", COUNT(*) AS cnt FROM tickets GROUP BY " + column;
            List<Map<String, Object>> rows = jdbc.queryForList(sql);
            for (Map<String, Object> row : rows) {
                Object val = row.get(column);
                if (val != null) {
                    String key = String.valueOf(val).toUpperCase();
                    Long count = ((Number) row.get("cnt")).longValue();
                    result.put(key, count);
                }
            }
        } catch (Exception e) {
            // Gracefully ignore SQL errors if column or table not present yet
        }
        return result;
    }
}
