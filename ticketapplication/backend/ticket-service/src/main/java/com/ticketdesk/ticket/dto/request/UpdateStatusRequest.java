package com.ticketdesk.ticket.dto.request;

import com.ticketdesk.ticket.enums.TicketStatus;
import jakarta.validation.constraints.NotNull;

public class UpdateStatusRequest {

    @NotNull(message = "Status is required")
    private TicketStatus status;

    public UpdateStatusRequest() {}

    public TicketStatus getStatus() { return status; }
    public void setStatus(TicketStatus status) { this.status = status; }
}
