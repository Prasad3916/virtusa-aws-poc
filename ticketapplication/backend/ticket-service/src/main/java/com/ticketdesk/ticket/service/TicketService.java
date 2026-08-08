package com.ticketdesk.ticket.service;

import com.ticketdesk.ticket.dto.request.AddCommentRequest;
import com.ticketdesk.ticket.dto.request.CreateTicketRequest;
import com.ticketdesk.ticket.dto.request.UpdateStatusRequest;
import com.ticketdesk.ticket.entity.Ticket;
import com.ticketdesk.ticket.enums.TicketPriority;
import com.ticketdesk.ticket.enums.TicketStatus;

import java.util.List;

public interface TicketService {
    Ticket createTicket(CreateTicketRequest request);
    List<Ticket> getAllTickets(TicketStatus status, TicketPriority priority, String assignedTo, String createdBy);
    Ticket getTicketById(Long id);
    Ticket updateStatus(Long id, UpdateStatusRequest request);
    Ticket assignTicket(Long id, String assignedTo);
    Ticket addComment(Long id, AddCommentRequest request);
    void deleteTicket(Long id);
}
