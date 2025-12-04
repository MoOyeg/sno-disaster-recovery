package com.example.resource;

import com.example.entity.Task;
import io.quarkus.qute.Template;
import io.quarkus.qute.TemplateInstance;
import io.smallrye.common.annotation.Blocking;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

import java.util.List;

@Path("/")
public class TaskUIResource {

    @Inject
    Template index;

    @GET
    @Produces(MediaType.TEXT_HTML)
    @Blocking
    public TemplateInstance get() {
        List<Task> tasks = Task.listAll();
        return index.data("tasks", tasks);
    }
}
