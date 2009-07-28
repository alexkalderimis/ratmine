package org.intermine.bio.web.widget;

/*
 * Copyright (C) 2002-2009 FlyMine
 *
 * This code may be freely distributed and modified under the
 * terms of the GNU Lesser General Public Licence.  This should
 * be distributed with the code.  See the LICENSE file for more
 * information or http://www.gnu.org/copyleft/lesser.html.
 *
 */

import org.intermine.objectstore.ObjectStore;
import org.intermine.pathquery.Constraints;
import org.intermine.pathquery.PathQuery;
import org.intermine.web.logic.bag.InterMineBag;
import org.intermine.web.logic.widget.WidgetURLQuery;


/**
 * {@inheritDoc}
 * @author Julie Sullivan
 */
public class PwStatURLQuery implements WidgetURLQuery
{
    //private static final Logger LOG = Logger.getLogger(GoStatURLQuery.class);
    private ObjectStore os;
    private InterMineBag bag;
    private String key;

    /**
     * @param os object store
     * @param key go terms user selected
     * @param bag bag page they were on
     */
    public PwStatURLQuery(ObjectStore os, InterMineBag bag, String key) {
        this.bag = bag;
        this.key = key;
        this.os = os;
    }

    /**
     * {@inheritDoc}
     */
    public PathQuery generatePathQuery() {

        PathQuery q = new PathQuery(os.getModel());
        String bagType = bag.getType();
        String pathStrings = "";

        String prefix = (bagType.equals("Protein") ? "Protein.genes" : "Gene");

        if (bagType.equals("Protein")) {
            pathStrings = "Protein.primaryAccession,";
        }

        pathStrings += prefix + ".primaryIdentifier,"
            + prefix + ".symbol,"
            + prefix + ".organism.name,"
            + prefix + ".pwAnnotation.PWTerm.identifier,"
            + prefix + ".pwAnnotation.PWTerm.name,"
            + prefix + ".pwAnnotation.PWTerm.relations.parentTerm.identifier,"
            + prefix + ".pwAnnotation.PWTerm.relations.parentTerm.name";

        q.setView(pathStrings);
        q.setOrderBy(pathStrings);

        q.addConstraint(bagType, Constraints.in(bag.getName()));

        // can't be a NOT relationship!
        String pathString = prefix + ".pwAnnotation.qualifier";
        q.addConstraint(pathString, Constraints.isNull());

        // go term
        pathString = prefix + ".pwAnnotation.PWTerm.relations.parentTerm";
        q.addConstraint(pathString, Constraints.lookup(key), "C", "PWTerm");

        q.setConstraintLogic("A and B and C");
        q.syncLogicExpression("and");
        return q;
    }
}
