import org.apache.jena.query.Dataset;
import org.apache.jena.query.DatasetFactory;
import org.apache.jena.riot.Lang;
import org.apache.jena.riot.RDFDataMgr;
import org.apache.jena.graph.Node;
import org.apache.jena.sparql.core.Quad;

import java.io.FileInputStream;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class JenaBenchmark {
    public static void main(String[] args) {
        String filename = "/home/thy/moonttl/bak/benchmark/test_100000.nq";

        try {
            long startTime = System.currentTimeMillis();
            
            // 创建 Dataset
            Dataset dataset = DatasetFactory.create();
            
            // 读取 NQ 文件
            try (InputStream in = new FileInputStream(filename)) {
                RDFDataMgr.read(dataset, in, Lang.NQUADS);
            }
            
            long endTime = System.currentTimeMillis();
            long elapsed = endTime - startTime;
            
            // 统计三元组/四元组数量
            long count = 0;
            Iterator<Quad> iter = dataset.asDatasetGraph().find(null, null, null, null);
            List<Quad> quads = new ArrayList<>();
            while (iter.hasNext()) {
                Quad quad = iter.next();
                quads.add(quad);
                count++;
            }
            
            System.out.println("解析时间: " + elapsed + " ms");
            System.out.println("四元组数量: " + count);
            System.out.println("每秒解析: " + (count * 1000 / elapsed));
            System.out.println("每四元组: " + (elapsed * 1.0 / count) + " ms");
            
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}