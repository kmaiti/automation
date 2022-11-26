package hello;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;


@RestController
public class ApiController {

    @RequestMapping("/version")
    public String version() {
        return "Version: 1.2.4";
    }
}
