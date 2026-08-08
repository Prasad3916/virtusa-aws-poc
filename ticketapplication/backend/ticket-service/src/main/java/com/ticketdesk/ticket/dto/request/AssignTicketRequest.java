package com.ticketdesk.ticket.dto.request;

import jakarta.validation.constraints.NotBlank;

public class AssignTicketRequest {

    @NotBlank(message = "Assigned user is required")
    private String assignedTo;

    public AssignTicketRequest() {}

    public AssignTicketRequest(String assignedTo) {
        this.assignedTo = assignedTo;
    }

    public String getAssignedTo() { return assignedTo; }
    public void setAssignedTo(String assignedTo) { this.assignedTo = assignedTo; }
}
