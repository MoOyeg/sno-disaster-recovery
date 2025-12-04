package com.example.resource;

import com.example.entity.Task;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.util.List;

@Path("/tasks")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class TaskResource {

    @GET
    public List<Task> getAllTasks() {
        return Task.listAll();
    }

    @GET
    @Path("/{id}")
    public Task getTask(@PathParam("id") Long id) {
        Task task = Task.findById(id);
        if (task == null) {
            throw new WebApplicationException("Task with id " + id + " not found", 404);
        }
        return task;
    }

    @POST
    @Transactional
    public Response createTask(Task task) {
        task.persist();
        return Response.status(Response.Status.CREATED).entity(task).build();
    }

    @PUT
    @Path("/{id}")
    @Transactional
    public Task updateTask(@PathParam("id") Long id, Task updatedTask) {
        Task task = Task.findById(id);
        if (task == null) {
            throw new WebApplicationException("Task with id " + id + " not found", 404);
        }
        task.title = updatedTask.title;
        task.description = updatedTask.description;
        task.completed = updatedTask.completed;
        return task;
    }

    @DELETE
    @Path("/{id}")
    @Transactional
    public Response deleteTask(@PathParam("id") Long id) {
        Task task = Task.findById(id);
        if (task == null) {
            throw new WebApplicationException("Task with id " + id + " not found", 404);
        }
        task.delete();
        return Response.noContent().build();
    }

    @GET
    @Path("/completed")
    public List<Task> getCompletedTasks() {
        return Task.list("completed", true);
    }

    @GET
    @Path("/pending")
    public List<Task> getPendingTasks() {
        return Task.list("completed", false);
    }
}
