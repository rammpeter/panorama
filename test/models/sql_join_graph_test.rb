require 'test_helper'

class SqlJoinGraphTest < ActiveSupport::TestCase
  SQL = "
    WITH cte AS (SELECT deptno, MAX(sal) m FROM scott.emp GROUP BY deptno)
    SELECT e.ename, d.dname, v.cnt
    FROM   emp e
    JOIN   dept d ON (d.deptno = e.deptno AND d.loc = 'X')
    LEFT OUTER JOIN (SELECT b.deptno, COUNT(*) cnt FROM bonus b WHERE b.comm > 0 GROUP BY b.deptno) v ON v.deptno = d.deptno
    , cte c, salgrade s
    WHERE  ((e.sal > :min_sal AND c.deptno = e.deptno))
    AND    e.sal BETWEEN s.losal AND s.hisal
    AND    s.grade(+) = 1
    AND    (e.job = 'CLERK' OR d.dname = 'SALES')
    AND    e.comm = e.sal
    AND    EXISTS (SELECT 1 FROM sys.audit_log a WHERE a.empno = e.empno)
    UNION ALL
    SELECT x, y, z FROM t1 WHERE (x = 5)"

  # Text of the label of the node with the given title
  def node_label(dot, title)
    dot.lines.find { |l| l["<B>#{title}</B>"] && l['[label=<'] }
  end

  test "build join graph" do
    result = SqlJoinGraph.build(SQL)
    dot = result[:dot]
    assert_equal [], result[:syntax_errors]
    assert dot['<B>WITH cte</B>>'],                                     'CTE cluster'
    assert dot['<B>Inline view v</B>'],                                 'Inline view cluster'
    assert dot['<B>Subquery in WHERE</B>'],                             'Subquery cluster'

    emp = node_label(dot, 'emp')
    assert emp['>sal&#160;&#160;<FONT COLOR="#1f4e9c">&gt; :min_sal</FONT>'], "Filter at attribute without parentheses: #{emp}"
    assert emp['comm = sal'],                                           "Filter with multiple attributes of one table: #{emp}"
    assert node_label(dot, 'dept')['= &#39;X&#39; (ON)'],              'Filter from ON clause'
    assert node_label(dot, 'salgrade')['>grade&#160;'],                 'Attribute with outer join marker (+)'
    assert node_label(dot, 't1')['>x&#160;&#160;<FONT COLOR="#1f4e9c">= 5</FONT>'], 'Unqualified filter for single table'

    assert_match(/n\d+:a\d+ -> n\d+:a\d+ \[label="=" tooltip="="\]/, dot,              'Join between attributes')
    assert_match(/n\d+:a\d+ -> n\d+:a\d+ \[label="=" tooltip="=" style=dashed\]/, dot, 'Outer join between attributes')
    assert dot['label="e.sal BETWEEN s.losal AND s.hisal"'],            'BETWEEN must not be split at its AND'
    assert dot['label="e.job = \'CLERK\' OR d.dname = \'SALES\'"'],     'Parentheses around OR removed'
    assert dot['label="EXISTS (…)"'],                                   'Link from subquery'
  end

  test "build join graph for DML statements" do
    dot = SqlJoinGraph.build("UPDATE ship_order_asgmt SET id_loading = :1, ts_upd = SYSDATE
                              WHERE id_order IN (SELECT id_ref_3 FROM pa_package WHERE id_site = :3 AND stat <= '70') AND id_site = :5")[:dot]
    assert dot['<B>UPDATE</B>'],                                        'UPDATE cluster'
    assert node_label(dot, 'ship_order_asgmt')['>id_site&#160;&#160;<FONT COLOR="#1f4e9c">= :5</FONT>'], 'Filter at target table of UPDATE'
    assert node_label(dot, 'pa_package')['>stat&#160;&#160;<FONT COLOR="#1f4e9c">&lt;= &#39;70&#39;</FONT>'], 'Filter in subquery of UPDATE'
    assert dot['label="id_order IN (…)"'],                             'Link from subquery to target table'

    dot = SqlJoinGraph.build("DELETE FROM t x WHERE x.a = 1 AND EXISTS (SELECT 1 FROM u WHERE u.b = x.b)")[:dot]
    assert dot['<B>DELETE</B>'],                                        'DELETE cluster'
    assert node_label(dot, 't')['&#160;x'],                             'Alias of target table'
    assert_match(/n\d+:a\d+ -> n\d+:a\d+ \[label="=" tooltip="="\]/, dot, 'Join between subquery and target table')

    dot = SqlJoinGraph.build("MERGE INTO t x USING u y ON (x.a = y.a) WHEN MATCHED THEN UPDATE SET x.b = y.b")[:dot]
    assert dot['<B>MERGE</B>'],                                         'MERGE cluster'
    assert_match(/n\d+:a\d+ -> n\d+:a\d+ \[label="=" tooltip="="\]/, dot, 'Join by ON condition of MERGE')

    dot = SqlJoinGraph.build("INSERT INTO t (a) SELECT b FROM u WHERE c = 1")[:dot]
    assert dot['<B>INSERT</B>'],                                        'INSERT cluster'
    assert node_label(dot, 'u')['>c&#160;&#160;<FONT COLOR="#1f4e9c">= 1</FONT>'], 'Filter in query of INSERT'
  end

  test "build join graph for invalid SQL" do
    assert_nothing_raised { SqlJoinGraph.build('SELECT FROM WHERE (((') }
  end
end
