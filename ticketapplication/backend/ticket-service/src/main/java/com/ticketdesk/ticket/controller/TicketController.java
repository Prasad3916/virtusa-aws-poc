package com.ticketdesk.ticket.controller;

import com.ticketdesk.ticket.dto.request.AddCommentRequest;
import com.ticketdesk.ticket.dto.request.AssignTicketRequest;
import com.ticketdesk.ticket.dto.request.CreateTicketRequest;
import com.ticketdesk.ticket.dto.request.UpdateStatusRequest;
import com.ticketdesk.ticket.dto.response.ApiResponse;
import com.ticketdesk.ticket.entity.Ticket;
import com.ticketdesk.ticket.enums.TicketPriority;
import com.ticketdesk.ticket.enums.TicketStatus;
import com.ticketdesk.ticket.service.TicketService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/tickets")
@CrossOrigin(origins = "*")
public class TicketController {

    private final TicketService ticketService;

    public TicketController(TicketService ticketService) {
        this.ticketService = ticketService;
    }

    /**
     * Create a new IT Ticket
     */
    @PostMapping
    public ResponseEntity<ApiResponse<Ticket>> createTicket(@Valid @RequestBody CreateTicketRequest request) {
        Ticket created = ticketService.createTicket(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success("Ticket created successfully", created));
    }

    /**
     * List and Filter Tickets (by status, priority, assignedTo, createdBy)
     */
    @GetMapping
    public ResponseEntity<ApiResponse<List<Ticket>>> getAllTickets(
            @RequestParam(value = "status", required = false) TicketStatus status,
            @RequestParam(value = "priority", required = false) TicketPriority priority,
            @RequestParam(value = "assignedTo", required = false) String assignedTo,
            @RequestParam(value = "createdBy", required = false) String createdBy) {
        
        List<Ticket> tickets = ticketService.getAllTickets(status, priority, assignedTo, createdBy);
        return ResponseEntity.ok(ApiResponse.success("Tickets retrieved successfully", tickets));
    }

    /**
     * Get single Ticket details
     */
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<Ticket>> getTicketById(@PathVariable("id") Long id) {
        Ticket ticket = ticketService.getTicketById(id);
        return ResponseEntity.ok(ApiResponse.success("Ticket details retrieved", ticket));
    }

    /**
     * Update Ticket Status (OPEN -> IN_PROGRESS -> RESOLVED -> CLOSED)
     */
    @PatchMapping("/{id}/status")
    public ResponseEntity<ApiResponse<Ticket>> updateStatus(
            @PathVariable("id") Long id,
            @Valid @RequestBody UpdateStatusRequest request) {
        
        Ticket updated = ticketService.updateStatus(id, request);
        return ResponseEntity.ok(ApiResponse.success("Ticket status updated to " + updated.getStatus(), updated));
    }

    /**
     * Assign Ticket to Agent (Admin feature)
     */
    @PatchMapping("/{id}/assign")
    public ResponseEntity<ApiResponse<Ticket>> assignTicket(
            @PathVariable("id") Long id,
            @Valid @RequestBody AssignTicketRequest request) {

        Ticket updated = ticketService.assignTicket(id, request.getAssignedTo());
        return ResponseEntity.ok(ApiResponse.success("Ticket assigned to " + updated.getAssignedTo(), updated));
    }

    /**
     * Add Comment to Ticket
     */
    @PostMapping("/{id}/comments")
    public ResponseEntity<ApiResponse<Ticket>> addComment(
            @PathVariable("id") Long id,
            @Valid @RequestBody AddCommentRequest request) {

        Ticket updated = ticketService.addComment(id, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success("Comment added successfully", updated));
    }

    /**
     * Delete Ticket — ADMIN only
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteTicket(@PathVariable("id") Long id) {
        ticketService.deleteTicket(id);
        return ResponseEntity.ok(ApiResponse.success("Ticket deleted successfully", null));
    }
}
