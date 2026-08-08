package com.ticketdesk.attachment.controller;

import com.ticketdesk.attachment.dto.ApiResponse;
import com.ticketdesk.attachment.entity.Attachment;
import com.ticketdesk.attachment.repository.AttachmentRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.MalformedURLException;
import java.nio.file.*;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/attachments")
@CrossOrigin(origins = "*")
public class AttachmentController {

    private final AttachmentRepository repo;

    @Value("${app.upload.dir:./uploads}")
    private String uploadDir;

    public AttachmentController(AttachmentRepository repo) {
        this.repo = repo;
    }

    /**
     * POST /api/v1/attachments/ticket/{ticketId}/upload
     * Upload a file and save metadata to DB.
     */
    @PostMapping("/ticket/{ticketId}/upload")
    public ResponseEntity<ApiResponse<Attachment>> upload(
            @PathVariable Long ticketId,
            @RequestParam("file") MultipartFile file) throws IOException {

        if (file.isEmpty()) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("File must not be empty"));
        }

        // Build target directory
        Path dir = Paths.get(uploadDir, String.valueOf(ticketId));
        Files.createDirectories(dir);

        // Unique file name to avoid collisions
        String uniqueName = UUID.randomUUID() + "_" + file.getOriginalFilename();
        Path target = dir.resolve(uniqueName);
        Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);

        // Persist metadata
        Attachment a = new Attachment();
        a.setTicketId(ticketId);
        a.setOriginalFileName(file.getOriginalFilename());
        a.setFileName(uniqueName);
        a.setContentType(file.getContentType());
        a.setFileSize(file.getSize());
        a.setStorageUrl("/uploads/" + ticketId + "/" + uniqueName);

        Attachment saved = repo.save(a);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success("File uploaded successfully", saved));
    }

    /**
     * GET /api/v1/attachments/ticket/{ticketId}
     * List all attachments for a ticket.
     */
    @GetMapping("/ticket/{ticketId}")
    public ResponseEntity<ApiResponse<List<Attachment>>> listByTicket(@PathVariable Long ticketId) {
        List<Attachment> attachments = repo.findByTicketId(ticketId);
        return ResponseEntity.ok(ApiResponse.success("Attachments retrieved", attachments));
    }

    /**
     * GET /api/v1/attachments/{id}/download
     * Stream the file back to the caller.
     */
    @GetMapping("/{id}/download")
    public ResponseEntity<Resource> download(@PathVariable Long id) {
        Attachment a = repo.findById(id).orElse(null);
        if (a == null) {
            return ResponseEntity.notFound().build();
        }

        try {
            Path filePath = Paths.get(uploadDir, String.valueOf(a.getTicketId()), a.getFileName());
            Resource resource = new UrlResource(filePath.toUri());
            if (!resource.exists()) {
                return ResponseEntity.notFound().build();
            }
            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType(
                            a.getContentType() != null ? a.getContentType() : MediaType.APPLICATION_OCTET_STREAM_VALUE))
                    .header(HttpHeaders.CONTENT_DISPOSITION,
                            "attachment; filename=\"" + a.getOriginalFileName() + "\"")
                    .body(resource);
        } catch (MalformedURLException e) {
            return ResponseEntity.internalServerError().build();
        }
    }

    /**
     * DELETE /api/v1/attachments/{id}
     * Delete metadata record and the physical file.
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        Attachment a = repo.findById(id).orElse(null);
        if (a == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error("Attachment not found with id: " + id));
        }

        // Delete physical file
        try {
            Path filePath = Paths.get(uploadDir, String.valueOf(a.getTicketId()), a.getFileName());
            Files.deleteIfExists(filePath);
        } catch (IOException ignored) { /* best-effort */ }

        repo.delete(a);
        return ResponseEntity.ok(ApiResponse.success("Attachment deleted", null));
    }
}
