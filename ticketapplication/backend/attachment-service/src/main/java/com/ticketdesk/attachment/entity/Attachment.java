package com.ticketdesk.attachment.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "attachments")
public class Attachment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long ticketId;

    private String originalFileName;
    private String fileName;
    private String contentType;
    private Long fileSize;

    @Column(length = 512)
    private String storageUrl;

    private LocalDateTime uploadedAt;

    @PrePersist
    protected void onCreate() {
        uploadedAt = LocalDateTime.now();
    }

    // Getters & Setters
    public Long getId()                    { return id; }
    public void setId(Long id)             { this.id = id; }

    public Long getTicketId()              { return ticketId; }
    public void setTicketId(Long ticketId) { this.ticketId = ticketId; }

    public String getOriginalFileName()                      { return originalFileName; }
    public void setOriginalFileName(String originalFileName) { this.originalFileName = originalFileName; }

    public String getFileName()                { return fileName; }
    public void setFileName(String fileName)   { this.fileName = fileName; }

    public String getContentType()                 { return contentType; }
    public void setContentType(String contentType) { this.contentType = contentType; }

    public Long getFileSize()              { return fileSize; }
    public void setFileSize(Long fileSize) { this.fileSize = fileSize; }

    public String getStorageUrl()                  { return storageUrl; }
    public void setStorageUrl(String storageUrl)   { this.storageUrl = storageUrl; }

    public LocalDateTime getUploadedAt()               { return uploadedAt; }
    public void setUploadedAt(LocalDateTime uploadedAt){ this.uploadedAt = uploadedAt; }
}
