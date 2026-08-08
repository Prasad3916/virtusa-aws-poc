package com.ticketdesk.ticket.controller;

import com.ticketdesk.ticket.dto.response.ApiResponse;
import com.ticketdesk.ticket.enums.TicketPriority;
import com.ticketdesk.ticket.enums.TicketStatus;
import com.ticketdesk.ticket.repository.TicketRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/dashboard")
@CrossOrigin(origins = "*")
public class DashboardController {

    private final TicketRepository ticketRepository;

    public DashboardController(TicketRepository ticketRepository) {
        this.ticketRepository = ticketRepository;
    }

    @GetMapping("/summary")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getDashboardSummary() {
        Map<String, Long> statusCounts = new HashMap<>();
        for (TicketStatus status : TicketStatus.values()) {
            statusCounts.put(status.name(), ticketRepository.countByStatus(status));
        }

        Map<String, Long> priorityCounts = new HashMap<>();
        for (TicketPriority priority : TicketPriority.values()) {
            priorityCounts.put(priority.name(), ticketRepository.countByPriority(priority));
        }

        Map<String, Object> data = new HashMap<>();
        data.put("totalTickets", ticketRepository.count());
        data.put("statusCounts", statusCounts);
        data.put("priorityCounts", priorityCounts);

        return ResponseEntity.ok(ApiResponse.success("Dashboard summary retrieved", data));
    }
}
