package com.ticketdesk.comment.controller;

import com.ticketdesk.comment.dto.AddCommentRequest;
import com.ticketdesk.comment.dto.ApiResponse;
import com.ticketdesk.comment.entity.TicketComment;
import com.ticketdesk.comment.repository.CommentRepository;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/comments")
@CrossOrigin(origins = "*")
public class CommentController {

    private final CommentRepository commentRepository;

    public CommentController(CommentRepository commentRepository) {
        this.commentRepository = commentRepository;
    }

    /**
     * POST /api/v1/comments
     * Add a new comment to a ticket.
     */
    @PostMapping
    public ResponseEntity<ApiResponse<TicketComment>> addComment(
            @Valid @RequestBody AddCommentRequest request) {

        TicketComment comment = new TicketComment();
        comment.setTicketId(request.getTicketId());
        comment.setContent(request.getContent());
        comment.setAuthor(request.getAuthor());   // null → @PrePersist default

        TicketComment saved = commentRepository.save(comment);
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(ApiResponse.success("Comment added successfully", saved));
    }

    /**
     * GET /api/v1/comments/ticket/{ticketId}
     * Retrieve all comments for a ticket, ordered by creation time (ascending).
     */
    @GetMapping("/ticket/{ticketId}")
    public ResponseEntity<ApiResponse<List<TicketComment>>> getCommentsByTicket(
            @PathVariable Long ticketId) {

        List<TicketComment> comments =
                commentRepository.findByTicketIdOrderByCreatedAtAsc(ticketId);
        return ResponseEntity.ok(
                ApiResponse.success("Comments retrieved successfully", comments));
    }

    /**
     * GET /api/v1/comments/ticket/{ticketId}/count
     * Return the total number of comments for a ticket.
     */
    @GetMapping("/ticket/{ticketId}/count")
    public ResponseEntity<ApiResponse<Long>> countCommentsByTicket(
            @PathVariable Long ticketId) {

        long count = commentRepository.countByTicketId(ticketId);
        return ResponseEntity.ok(
                ApiResponse.success("Comment count retrieved", count));
    }

    /**
     * DELETE /api/v1/comments/{id}
     * Delete a comment by its ID.
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteComment(@PathVariable Long id) {
        if (!commentRepository.existsById(id)) {
            return ResponseEntity
                    .status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error("Comment not found with id: " + id));
        }
        commentRepository.deleteById(id);
        return ResponseEntity.ok(ApiResponse.success("Comment deleted successfully", null));
    }
}
