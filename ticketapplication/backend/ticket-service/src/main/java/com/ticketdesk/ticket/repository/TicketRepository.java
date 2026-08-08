package com.ticketdesk.ticket.repository;

import com.ticketdesk.ticket.entity.Ticket;
import com.ticketdesk.ticket.enums.TicketPriority;
import com.ticketdesk.ticket.enums.TicketStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TicketRepository extends JpaRepository<Ticket, Long> {
    List<Ticket> findByStatus(TicketStatus status);
    List<Ticket> findByPriority(TicketPriority priority);
    List<Ticket> findByAssignedTo(String assignedTo);
    List<Ticket> findByCreatedBy(String createdBy);
    long countByStatus(TicketStatus status);
    long countByPriority(TicketPriority priority);
}
