package com.ticketdesk.comment.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public class AddCommentRequest {

    @NotNull(message = "ticketId is required")
    private Long ticketId;

    @NotBlank(message = "content must not be blank")
    @Size(max = 2000, message = "content must not exceed 2000 characters")
    private String content;

    private String author;

    // ── Getters & Setters ────────────────────────────────────────────────────

    public Long getTicketId() {
        return ticketId;
    }

    public void setTicketId(Long ticketId) {
        this.ticketId = ticketId;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }

    public String getAuthor() {
        return author;
    }

    public void setAuthor(String author) {
        this.author = author;
    }
}
