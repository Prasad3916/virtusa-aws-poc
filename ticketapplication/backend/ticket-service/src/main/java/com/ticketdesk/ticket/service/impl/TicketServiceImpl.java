package com.ticketdesk.ticket.service.impl;

import com.ticketdesk.ticket.dto.request.AddCommentRequest;
import com.ticketdesk.ticket.dto.request.CreateTicketRequest;
import com.ticketdesk.ticket.dto.request.UpdateStatusRequest;
import com.ticketdesk.ticket.entity.Comment;
import com.ticketdesk.ticket.entity.Ticket;
import com.ticketdesk.ticket.enums.TicketPriority;
import com.ticketdesk.ticket.enums.TicketStatus;
import com.ticketdesk.ticket.exception.ResourceNotFoundException;
import com.ticketdesk.ticket.repository.TicketRepository;
import com.ticketdesk.ticket.service.TicketService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class TicketServiceImpl implements TicketService {

    private static final Logger log = LoggerFactory.getLogger(TicketServiceImpl.class);
    private final TicketRepository ticketRepository;

    public TicketServiceImpl(TicketRepository ticketRepository) {
        this.ticketRepository = ticketRepository;
    }

    @Override
    public Ticket createTicket(CreateTicketRequest request) {
        log.info("Creating new ticket: title='{}', priority={}, category={}, createdBy={}", 
                request.getTitle(), request.getPriority(), request.getCategory(), request.getCreatedBy());
        Ticket ticket = new Ticket(
                request.getTitle(),
                request.getDescription(),
                request.getCategory(),
                request.getPriority()
        );
        if (request.getCreatedBy() != null && !request.getCreatedBy().isBlank()) {
            ticket.setCreatedBy(request.getCreatedBy());
        }
        return ticketRepository.save(ticket);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Ticket> getAllTickets(TicketStatus status, TicketPriority priority, String assignedTo, String createdBy) {
        log.info("Fetching tickets with filters - status: {}, priority: {}, assignedTo: {}, createdBy: {}", 
                status, priority, assignedTo, createdBy);
        
        if (assignedTo != null && !assignedTo.isBlank()) {
            return ticketRepository.findByAssignedTo(assignedTo);
        } else if (createdBy != null && !createdBy.isBlank()) {
            return ticketRepository.findByCreatedBy(createdBy);
        } else if (status != null) {
            return ticketRepository.findByStatus(status);
        } else if (priority != null) {
            return ticketRepository.findByPriority(priority);
        }
        return ticketRepository.findAll();
    }

    @Override
    @Transactional(readOnly = true)
    public Ticket getTicketById(Long id) {
        log.info("Fetching ticket by ID: {}", id);
        return ticketRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Ticket not found with ID: " + id));
    }

    @Override
    public Ticket updateStatus(Long id, UpdateStatusRequest request) {
        log.info("Updating status for ticket ID {} to {}", id, request.getStatus());
        Ticket ticket = getTicketById(id);
        ticket.setStatus(request.getStatus());
        return ticketRepository.save(ticket);
    }

    @Override
    public Ticket assignTicket(Long id, String assignedTo) {
        log.info("Assigning ticket ID {} to {}", id, assignedTo);
        Ticket ticket = getTicketById(id);
        ticket.setAssignedTo(assignedTo);
        return ticketRepository.save(ticket);
    }

    @Override
    public Ticket addComment(Long id, AddCommentRequest request) {
        log.info("Adding comment to ticket ID {} by author {}", id, request.getAuthor());
        Ticket ticket = getTicketById(id);
        Comment comment = new Comment(request.getContent(), request.getAuthor());
        ticket.getComments().add(comment);
        return ticketRepository.save(ticket);
    }

    @Override
    public void deleteTicket(Long id) {
        log.info("Deleting ticket ID {}", id);
        Ticket ticket = getTicketById(id);
        ticketRepository.delete(ticket);
    }
}
