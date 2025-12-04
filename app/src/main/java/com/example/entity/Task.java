package com.example.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import jakarta.validation.constraints.NotBlank;

@Entity
@Table(name = "tasks")
public class Task extends PanacheEntity {
    
    @NotBlank
    public String title;
    
    public String description;
    
    public boolean completed;
    
    public Task() {
    }
    
    public Task(String title, String description) {
        this.title = title;
        this.description = description;
        this.completed = false;
    }
}
